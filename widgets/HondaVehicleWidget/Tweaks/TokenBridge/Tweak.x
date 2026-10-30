//
//  TokenBridge — 越狱桥接：把东风本田 App 拿到的车况写进共享 plist
//  目标: com.szlanyou.HondaOneIOV
//  产物: /var/mobile/Library/Preferences/com.yg.hondawidget.status.plist
//  小组件通过 SharedStore.load() 的「兜底路径」读它
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <substrate.h>

#define BRIDGE_PLIST @"/var/mobile/Library/Preferences/com.yg.hondawidget.status.plist"

#pragma mark - 取值

static id JBDig(id node, NSArray<NSString *> *keys) {
    if ([node isKindOfClass:[NSDictionary class]]) {
        for (NSString *k in keys) {
            id v = ((NSDictionary *)node)[k];
            if (v) return v;
        }
        for (id v in [(NSDictionary *)node allValues]) {
            id r = JBDig(v, keys);
            if (r) return r;
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id v in (NSArray *)node) {
            id r = JBDig(v, keys);
            if (r) return r;
        }
    }
    return nil;
}

static double JBNum(id v, double def) {
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v doubleValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v doubleValue];
    return def;
}

static BOOL JBBool(id v, BOOL def) {
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v boolValue];
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)v lowercaseString];
        return [s isEqualToString:@"1"] || [s isEqualToString:@"true"] ||
               [s isEqualToString:@"locked"] || [s isEqualToString:@"closed"] ||
               [s isEqualToString:@"on"];
    }
    return def;
}

static NSString *JBStr(id v, NSString *def) {
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
    return def;
}

#pragma mark - 落盘

static void JBBridgeWriteRoot(NSDictionary *root) {
    if (![root isKindOfClass:[NSDictionary class]]) return;

    id energyV = JBDig(root, @[@"oilPercent", @"fuelPercent", @"soc", @"batteryLevel", @"oil"]);
    double energy = JBNum(energyV, -1);
    if (energy < 0) return;
    if (energy > 1) energy /= 100.0;

    NSString *kindRaw = [JBStr(JBDig(root, @[@"energyType", @"powerType", @"fuelType"]), @"fuel") lowercaseString];
    NSString *kind = @"fuel";
    if ([kindRaw containsString:@"电"] || [kindRaw containsString:@"ev"] || [kindRaw containsString:@"batt"]) kind = @"battery";
    else if ([kindRaw containsString:@"混"] || [kindRaw containsString:@"hybrid"]) kind = @"hybrid";

    NSString *vin = JBStr(JBDig(root, @[@"vin", @"VIN", @"vinCode"]), @"");

    NSMutableDictionary *out = [@{
        @"vin": vin,
        @"nickname": JBStr(JBDig(root, @[@"nickName", @"vehicleName", @"carName", @"alias"]), @"我的车"),
        @"modelName": JBStr(JBDig(root, @[@"modelName", @"seriesName", @"vehicleModel"]), @""),
        @"energy": @(energy),
        @"energyKind": kind,
        @"range": @((int)JBNum(JBDig(root, @[@"range", @"endurance", @"remainRange", @"evRange"]), 0)),
        @"odometer": @((int)JBNum(JBDig(root, @[@"odometer", @"mileage", @"totalMileage"]), 0)),
        @"doorsLocked": @(JBBool(JBDig(root, @[@"doorLock", @"lockStatus", @"doorsLocked"]), YES)),
        @"windowsClosed": @(JBBool(JBDig(root, @[@"windowStatus", @"windowsClosed"]), YES)),
        @"trunkClosed": @(JBBool(JBDig(root, @[@"trunkStatus", @"trunkClosed"]), YES)),
        @"acOn": @(JBBool(JBDig(root, @[@"acStatus", @"acOn", @"climateOn"]), NO)),
        @"ts": @([[NSDate date] timeIntervalSince1970]),
    } mutableCopy];

    id cabin = JBDig(root, @[@"inTemp", @"cabinTemp", @"insideTemp"]);
    if (cabin) out[@"cabinTemp"] = @(JBNum(cabin, 0));

    BOOL ok = [out writeToFile:BRIDGE_PLIST atomically:YES];
    NSLog(@"[TokenBridge] bridge write %@ (%lu keys, energy=%.2f)", ok ? @"OK" : @"FAIL",
          (unsigned long)out.count, energy);
}

static void JBBridgeParseData(NSData *data) {
    if (!data.length) return;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if ([json isKindOfClass:[NSDictionary class]]) JBBridgeWriteRoot(json);
}

#pragma mark - 网络层嗅探

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *url = request.URL.absoluteString ?: @"";
    BOOL interesting = [url containsString:@"/status"] ||
                       [url containsString:@"vehicle"] ||
                       [url containsString:@"condition"] ||
                       [url containsString:@"remote"];

    if (!interesting || !handler) return %orig;

    void (^wrapped)(NSData *, NSURLResponse *, NSError *) =
        ^(NSData *data, NSURLResponse *resp, NSError *err) {
            JBBridgeParseData(data);
            handler(data, resp, err);
        };
    return %orig(request, wrapped);
}
%end

#pragma mark - 兜底：车况模型 setter 反射

static void JBScanModelSetters(void) {
    static const char *kWords[] = { "vehiclestatus", "carstatus", "vehicledata", "carkey", "vehicleinfo", NULL };
    int n = objc_getClassList(NULL, 0);
    if (n <= 0) return;
    Class *list = (Class *)malloc(sizeof(Class) * n);
    n = objc_getClassList(list, n);

    for (int i = 0; i < n; i++) {
        Class cls = list[i];
        if (!cls) continue;
        unsigned mc = 0;
        Method *ms = class_copyMethodList(cls, &mc);
        for (unsigned j = 0; j < mc; j++) {
            const char *sn = sel_getName(method_getName(ms[j]));
            if (!sn || strncmp(sn, "set", 3) != 0) continue;
            char low[256] = {0};
            size_t L = strlen(sn);
            if (L >= sizeof(low)) continue;
            for (size_t k = 0; k < L; k++) low[k] = (char)tolower((unsigned char)sn[k]);
            BOOL hit = NO;
            for (int k = 0; kWords[k]; k++) if (strstr(low, kWords[k])) { hit = YES; break; }
            if (!hit) continue;
            NSLog(@"[TokenBridge] model setter: -[%s %s]", class_getName(cls), sn);
        }
        free(ms);
    }
    free(list);
}

%ctor {
    @autoreleasepool {
        NSLog(@"[TokenBridge] loaded, bridge=%@", BRIDGE_PLIST);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ JBScanModelSetters(); });
    }
}
