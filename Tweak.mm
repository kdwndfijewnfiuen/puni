//
// YWPOverlay - Yo-kai Watch Puni Puni status overlay
// Displays: active deck (5), hitodama, Y-money, Y-point
//
// Build:  cd YWPOverlay && make package
// Install: onto device with Substrate/Substitute/libhooker
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>

#pragma mark - Config

// 更新間隔（秒）
static const NSTimeInterval kRefreshInterval = 0.5;

// 起動後オーバーレイ表示までの遅延
static const NSTimeInterval kSetupDelay = 3.0;

// オーバーレイ見た目
static const CGFloat kPanelW = 170;
static const CGFloat kPanelH = 110;
static const CGFloat kPanelX = 8;
static const CGFloat kPanelY = 54;

#pragma mark - Game data readers (TODO: fill offsets)

/*
 * ここを H5Frida / メモリ検索で埋める。
 *
 * プロトコル上のフィールド名（バイナリ内）:
 *   ymoney, chargeYmoney, freeHitodama, hitodama
 *   activeDeckId, youkaiIdList
 *
 * 手順例:
 *  1. 人魂を1消費して前後でメモリ検索
 *  2. 安定ポインタ or UserData からのオフセットを特定
 *  3. 下記 read* を実装
 */

// メインバイナリのスライド付きアドレスを得る
static uintptr_t YWPBase(void) {
    static uintptr_t base = 0;
    if (base) return base;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "/YWP.app/YWP")) {
            base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    return base;
}

static bool safeRead(uintptr_t addr, void *buf, size_t len) {
    if (!addr || !buf || !len) return false;
    vm_size_t out = 0;
    kern_return_t kr = vm_read_overwrite(
        mach_task_self(),
        (vm_address_t)addr,
        (vm_size_t)len,
        (vm_address_t)buf,
        &out);
    return kr == KERN_SUCCESS && out == len;
}

static int readI32(uintptr_t addr, int fallback) {
    int v = fallback;
    if (!safeRead(addr, &v, sizeof(v))) return fallback;
    return v;
}

// ---- 実装してください ----

// UserData ベースアドレス（例: グローバルポインタを辿る）
static uintptr_t getUserDataPtr(void) {
    // TODO: 例
    // uintptr_t base = YWPBase();
    // uintptr_t global = base + 0xXXXXXXXX;  // 静的ポインタ
    // uintptr_t ptr = 0;
    // if (!safeRead(global, &ptr, sizeof(ptr))) return 0;
    // return ptr;
    return 0;
}

static int readYmoney(void) {
    uintptr_t ud = getUserDataPtr();
    if (!ud) return -1;
    // TODO: return readI32(ud + 0xYYY, -1);
    return -1;
}

static int readYpoint(void) {
    uintptr_t ud = getUserDataPtr();
    if (!ud) return -1;
    // TODO: return readI32(ud + 0xYYY, -1);
    return -1;
}

static int readHitodama(void) {
    uintptr_t ud = getUserDataPtr();
    if (!ud) return -1;
    // TODO: return readI32(ud + 0xYYY, -1);
    return -1;
}

// アクティブデッキの妖怪ID 5体（無いスロットは 0）
static void readDeckIds(int outIds[5]) {
    for (int i = 0; i < 5; i++) outIds[i] = 0;
    uintptr_t ud = getUserDataPtr();
    if (!ud) return;
    // TODO: deck 配列の先頭 + stride で 5 体読む
    // for (int i = 0; i < 5; i++)
    //     outIds[i] = readI32(deckBase + i * stride, 0);
}

#pragma mark - Overlay UI

@interface YWPOverlayView : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL collapsed;
@end

@implementation YWPOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.72];
        self.layer.cornerRadius = 12;
        self.layer.masksToBounds = YES;
        self.collapsed = NO;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, frame.size.width - 16, 18)];
        _titleLabel.text = @"YWP Overlay";
        _titleLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1];
        _titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _titleLabel.userInteractionEnabled = YES;
        [self addSubview:_titleLabel];

        _bodyLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 24, frame.size.width - 16, frame.size.height - 30)];
        _bodyLabel.textColor = [UIColor whiteColor];
        _bodyLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        _bodyLabel.numberOfLines = 0;
        _bodyLabel.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_bodyLabel];

        UIPanGestureRecognizer *pan =
            [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
        [self addGestureRecognizer:pan];

        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
        tap.numberOfTapsRequired = 2;
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *parent = self.superview;
    if (!parent) return;
    CGPoint t = [g translationInView:parent];
    CGPoint c = self.center;
    c.x += t.x;
    c.y += t.y;
    // 画面内に収める
    CGFloat hw = self.bounds.size.width * 0.5;
    CGFloat hh = self.bounds.size.height * 0.5;
    c.x = MIN(MAX(c.x, hw), parent.bounds.size.width - hw);
    c.y = MIN(MAX(c.y, hh), parent.bounds.size.height - hh);
    self.center = c;
    [g setTranslation:CGPointZero inView:parent];
}

- (void)onTap:(UITapGestureRecognizer *)g {
    self.collapsed = !self.collapsed;
    self.bodyLabel.hidden = self.collapsed;
    CGRect f = self.frame;
    f.size.height = self.collapsed ? 26 : kPanelH;
    self.frame = f;
}

- (void)refresh {
    int ids[5];
    readDeckIds(ids);

    int ym = readYmoney();
    int yp = readYpoint();
    int hd = readHitodama();

    NSString *ymS = ym < 0 ? @"---" : [NSString stringWithFormat:@"%d", ym];
    NSString *ypS = yp < 0 ? @"---" : [NSString stringWithFormat:@"%d", yp];
    NSString *hdS = hd < 0 ? @"---" : [NSString stringWithFormat:@"%d", hd];

    self.bodyLabel.text = [NSString stringWithFormat:
        @"Y$ %@\nYP %@\n人魂 %@\n"
        @"デッキ\n%d  %d  %d  %d  %d",
        ymS, ypS, hdS,
        ids[0], ids[1], ids[2], ids[3], ids[4]];
}

- (void)startTimer {
    [self.timer invalidate];
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:kRefreshInterval
                                                 repeats:YES
                                                   block:^(__unused NSTimer *t) {
        [weakSelf refresh];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self refresh];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

@end

#pragma mark - Setup

static const NSInteger kOverlayTag = 0x5957504F; // 'YWPO'

static UIWindow *pickWindow(void) {
    UIWindow *key = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) { key = w; break; }
            }
            if (key) break;
            if (!key && ws.windows.count) key = ws.windows.firstObject;
        }
    }
    if (!key) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        key = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    if (!key) key = [UIApplication sharedApplication].windows.firstObject;
    return key;
}

static void setupOverlay(void) {
    UIWindow *win = pickWindow();
    if (!win) return;
    if ([win viewWithTag:kOverlayTag]) return;

    CGRect frame = CGRectMake(kPanelX, kPanelY, kPanelW, kPanelH);
    YWPOverlayView *view = [[YWPOverlayView alloc] initWithFrame:frame];
    view.tag = kOverlayTag;
    [win addSubview:view];
    [view startTimer];
}

#pragma mark - ctor

%ctor {
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSetupDelay * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            setupOverlay();
        });
}
