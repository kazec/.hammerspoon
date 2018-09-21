@import Cocoa;
@import LuaSkin;

#pragma mark - Interfaces

@interface HotCornerWindow : NSPanel

@property (nonatomic) int luaRef;

@end

@interface HotCornerView : NSView

@property int luaRef;
@property int mouseUpCallbackRef;
@property int mouseDownCallbackRef;
@property int mouseEnteredCallbackRef;
@property int mouseExitedCallbackRef;
@property int mouseClickCallbackRef;
@property int mouseHoverCallbackRef;
@property int scrollWheelCallbackRef;
@property (nonatomic) NSInteger maxClickCount;
@property (nonatomic) NSTimeInterval multiClickInterval;
@property (nonatomic) BOOL ignoreFlagsChanges;
@property (nonatomic) BOOL ignoreMomentumScrolling;

@end

#pragma mark - Supporting Variables & Functions

static const char *USERDATA_TAG = "hotcorner";
static int refTable = LUA_NOREF;

static inline void flipRectYCoordinate(NSRect *rect) {
    rect->origin.y = [[NSScreen screens][0] frame].size.height - rect->origin.y - rect->size.height;
}

static inline void pushHotCornerWindow(lua_State *L, HotCornerWindow *window) {
    LuaSkin *skin = [LuaSkin shared];

    if (window.luaRef == LUA_NOREF) {
        void** userdataPointer = lua_newuserdata(L, sizeof(HotCornerWindow *));
        *userdataPointer = (__bridge_retained void *)window;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        window.luaRef = [skin luaRef:refTable];
    }

    [skin pushLuaRef:refTable ref:window.luaRef];
}

static inline HotCornerWindow* bridgeToHotCornerWindow(lua_State *L, int idx) {
    return (__bridge HotCornerWindow*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG));
}

#pragma mark - HotCornerWindow

@implementation HotCornerWindow
-(instancetype) initWithContentRect:(NSRect)contentRect {
    if (!(isfinite(contentRect.origin.x) && isfinite(contentRect.origin.y) && isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        [[LuaSkin shared] logError:[NSString stringWithFormat:@"%s:coordinates must be finite numbers", USERDATA_TAG]];
        return nil;
    }

    self = [super initWithContentRect:contentRect
                            styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                              backing:NSBackingStoreBuffered
                                defer:YES];

    if (self) {
        self.backgroundColor      = [NSColor clearColor];
        self.opaque               = NO;
        self.hasShadow            = NO;
        self.ignoresMouseEvents   = NO;
        self.restorable           = NO;
        self.hidesOnDeactivate    = NO;
        self.animationBehavior    = NSWindowAnimationBehaviorNone;
        self.collectionBehavior   = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary;
        self.level                = NSPopUpMenuWindowLevel;
        self.accessibilitySubrole = @"Hammerspoon Hotcorner";
    } else {
        [[LuaSkin shared] logError:@"Failed to create HotCornerWindow."];
    }

    return self;
}

-(int)luaRef {
    return ((HotCornerView *)self.contentView).luaRef;
}

-(void)setLuaRef:(int)ref {
    ((HotCornerView *)self.contentView).luaRef = ref;
}

- (BOOL)windowShouldClose:(__unused id)sender {
    return NO;
}

- (BOOL)canBecomeKeyWindow {
    NSPoint mouseLocation = [NSEvent mouseLocation];
    return NSPointInRect(mouseLocation, self.frame);
}

@end

#pragma mark - HotCornerView

@implementation HotCornerView {
    NSTrackingRectTag trackingRectTag;
    NSTimer *mouseClickTimer;
    NSTimer *mouseHoverTimer;
}

-(instancetype) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        trackingRectTag = NSNotFound;
        mouseClickTimer = nil;
        mouseHoverTimer = nil;

        self.luaRef = LUA_NOREF;

        self.mouseUpCallbackRef      = LUA_NOREF;
        self.mouseDownCallbackRef    = LUA_NOREF;
        self.mouseEnteredCallbackRef = LUA_NOREF;
        self.mouseExitedCallbackRef  = LUA_NOREF;
        self.mouseClickCallbackRef   = LUA_NOREF;
        self.mouseHoverCallbackRef   = LUA_NOREF;
        self.scrollWheelCallbackRef  = LUA_NOREF;

        self.maxClickCount = 2;
        self.multiClickInterval = 0.3;
        self.ignoreFlagsChanges = NO;
        self.ignoreMomentumScrolling = YES;
    }
    return self;
}

- (void)viewWillMoveToWindow:(__unused NSWindow *)newWindow {
    if (self.window && trackingRectTag != NSNotFound) {
        [self removeTrackingRect:trackingRectTag];
        trackingRectTag = NSNotFound;
    }
}

- (void)viewDidMoveToWindow {
    if (self.window != nil) {
        trackingRectTag = [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:NO];
    }
    [super viewDidMoveToWindow];
}

- (void)updateTrackingAreas {
    [self removeTrackingRect:trackingRectTag];
    trackingRectTag = [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:NO];
    [super updateTrackingAreas];
}

- (BOOL)acceptsFirstMouse:(__unused NSEvent *)theEvent {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)invalidateTimers {
    if (mouseClickTimer != nil) {
        [mouseClickTimer invalidate];
        mouseClickTimer = nil;
    }
    if (mouseHoverTimer != nil) {
        [mouseHoverTimer invalidate];
        mouseHoverTimer = nil;
    }
}

- (void)setMaxClickCount:(NSInteger)maxClickCount {
    if (maxClickCount < 1) {
        _maxClickCount = 1;
    } else {
        _maxClickCount = maxClickCount;
    }
}

- (void)setMultiClickInterval:(NSTimeInterval)multiClickInterval {
    if (multiClickInterval < 0.0) {
        _multiClickInterval = 0.0;
    } else {
        _multiClickInterval = multiClickInterval;
    }
}

#pragma mark - Handle Mouse Events
- (void)invokeMouseUpDownCallbackWithLocation:(NSPoint)location clickCount:(lua_Integer)clickCount
                                modifierFlags:(NSEventModifierFlags)modifierFlags left:(BOOL)leftMouse up:(BOOL)mouseUp {
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    [skin pushLuaRef:refTable ref:mouseUp ? _mouseUpCallbackRef : _mouseDownCallbackRef];
    [skin pushLuaRef:refTable ref:_luaRef]; // hotcorner userdata object
    [skin pushNSPoint:location]; // location
    lua_pushinteger(L, clickCount); // clickCount
    lua_pushinteger(L, (lua_Integer)(modifierFlags & NSDeviceIndependentModifierFlagsMask)); // modifierFlags
    lua_pushboolean(L, leftMouse); // leftMouse

    if (![skin protectedCallAndTraceback:5 nresults:0]) {
        [skin logError:[NSString stringWithFormat:@"%s \"%s\" callback error: %s",
                        USERDATA_TAG,
                        mouseUp ? "mouseUp" : "mouseDown",
                        lua_tostring(L, -1)]];
        lua_pop(L, 1);
    }
}

- (void)invokeMouseClickCallbackWithLocation:(NSPoint)location clickCount:(NSInteger)clickCount modifierFlags:(NSEventModifierFlags)modifierFlags {
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    [skin pushLuaRef:refTable ref:_mouseClickCallbackRef];
    [skin pushLuaRef:refTable ref:_luaRef]; // hotcorner userdata object
    [skin pushNSPoint:location]; // location
    lua_pushinteger(L, clickCount); // clickCount
    lua_pushinteger(L, (lua_Integer)(modifierFlags & NSDeviceIndependentModifierFlagsMask)); // modifierFlags

    if (![skin protectedCallAndTraceback:4 nresults:0]) {
        [skin logError:[NSString stringWithFormat:@"%s \"mouseClick\" callback error: %s",
                        USERDATA_TAG,
                        lua_tostring(L, -1)]];
        lua_pop(L, 1);
    }
}

- (void)onMultiClickTimedout:(NSTimer *)timer {
    if (_mouseClickCallbackRef != LUA_NOREF) {
        NSEvent *event = (NSEvent *)timer.userInfo;
        [self invokeMouseClickCallbackWithLocation:event.locationInWindow
                                        clickCount:event.clickCount
                                     modifierFlags:event.modifierFlags];
    }
    mouseClickTimer = nil;
}

- (void)mouseUp:(NSEvent *)event {
    if (_mouseUpCallbackRef != LUA_NOREF) {
        [self invokeMouseUpDownCallbackWithLocation:event.locationInWindow
                                         clickCount:event.clickCount
                                      modifierFlags:event.modifierFlags
                                               left:YES
                                                 up:YES];
    }

    if (_mouseClickCallbackRef != LUA_NOREF && event.clickCount > 0) {
        if (mouseClickTimer != nil) {
            [mouseClickTimer invalidate];
            mouseClickTimer = nil;
        }

        if (event.clickCount == _maxClickCount) {
            [self invokeMouseClickCallbackWithLocation:event.locationInWindow
                                            clickCount:event.clickCount
                                         modifierFlags:event.modifierFlags];
        } else if (event.clickCount < _maxClickCount) {
            mouseClickTimer = [NSTimer scheduledTimerWithTimeInterval:_multiClickInterval
                                                               target:self
                                                             selector:@selector(onMultiClickTimedout:)
                                                             userInfo:event
                                                              repeats:false];
        }
    }
}

- (void)mouseDown:(NSEvent *)event {
    if (_mouseDownCallbackRef != LUA_NOREF) {
        [self invokeMouseUpDownCallbackWithLocation:event.locationInWindow
                                         clickCount:event.clickCount
                                      modifierFlags:event.modifierFlags
                                               left:YES
                                                 up:NO];
    }
}

- (void)rightMouseUp:(NSEvent *)event {
    if (_mouseUpCallbackRef != LUA_NOREF) {
        [self invokeMouseUpDownCallbackWithLocation:event.locationInWindow
                                         clickCount:event.clickCount
                                      modifierFlags:event.modifierFlags
                                               left:NO
                                                 up:YES];
    }
}

- (void)rightMouseDown:(NSEvent *)event {
    if (_mouseDownCallbackRef != LUA_NOREF) {
        [self invokeMouseUpDownCallbackWithLocation:event.locationInWindow
                                         clickCount:event.clickCount
                                      modifierFlags:event.modifierFlags
                                               left:NO
                                                 up:NO];
    }
}

- (void)invokeMouseEnteredExitedCallbackWithLocation:(NSPoint)location modifierFlags:(NSEventModifierFlags)modifierFlags entered:(BOOL)entered {
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    [skin pushLuaRef:refTable ref:entered ? _mouseEnteredCallbackRef : _mouseExitedCallbackRef];
    [skin pushLuaRef:refTable ref:_luaRef]; // hotcorner userdata object
    [skin pushNSPoint:location]; // location
    lua_pushinteger(L, (lua_Integer)(modifierFlags & NSDeviceIndependentModifierFlagsMask)); // modifierFlags

    if (![skin protectedCallAndTraceback:3 nresults:0]) {
        [skin logError:[NSString stringWithFormat:@"%s \"%s\" callback error: %s",
                        USERDATA_TAG,
                        entered ? "mouseEntered" : "mouseExited",
                        lua_tostring(L, -1)]];
        lua_pop(L, 1);
    }
}

- (void)invokeMouseHoverCallbackWithDelay:(NSTimeInterval)currentDelay since:(NSTimeInterval)initial location:(NSPoint)location
                            modifierFlags:(NSEventModifierFlags)modifierFlags flagsChanged:(BOOL)flagsChanged {
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    [skin pushLuaRef:refTable ref:_mouseHoverCallbackRef];
    [skin pushLuaRef:refTable ref:_luaRef]; // hotcorner userdata object
    [skin pushNSPoint:location]; // location
    lua_pushnumber(L, currentDelay); // current delay
    lua_pushinteger(L, (lua_Integer)(modifierFlags & NSDeviceIndependentModifierFlagsMask)); // modifierFlags
    lua_pushboolean(L, flagsChanged); // flagsChanged

    if (![skin protectedCallAndTraceback:5 nresults:1]) {
        [skin logError:[NSString stringWithFormat:@"%s \"mouseHover\" callback error: %s",
                        USERDATA_TAG,
                        lua_tostring(L, -1)]];
        lua_pop(L, 1);
    } else {
        NSTimeInterval nextDelay = lua_tonumberx(L, -1, NULL);
        lua_pop(L, 1);

        if (nextDelay > 0) {
            currentDelay = NSProcessInfo.processInfo.systemUptime - initial;
            mouseHoverTimer = [NSTimer scheduledTimerWithTimeInterval:nextDelay - currentDelay
                                                               target:self
                                                             selector:@selector(onMouseHoverTimedout:)
                                                             userInfo:[NSNumber numberWithDouble:initial]
                                                              repeats:false];
        }
    }
}

- (void)onMouseHoverTimedout:(NSTimer *)timer {
    if (_mouseHoverCallbackRef == LUA_NOREF) {
        mouseHoverTimer = nil;
        return;
    }

    NSTimeInterval initial = ((NSNumber *)timer.userInfo).doubleValue;
    [self invokeMouseHoverCallbackWithDelay:NSProcessInfo.processInfo.systemUptime - initial
                                      since:initial
                                   location:self.window.mouseLocationOutsideOfEventStream
                              modifierFlags:NSEvent.modifierFlags
                               flagsChanged:NO];
}

- (void)mouseEntered:(NSEvent *)event {
    [self invalidateTimers];

    if (_ignoreFlagsChanges) {
        [self.window orderFront:nil];
    } else {
        [self.window makeKeyAndOrderFront:nil];
    }

    if (_mouseEnteredCallbackRef != LUA_NOREF) {
        [self invokeMouseEnteredExitedCallbackWithLocation:event.locationInWindow
                                             modifierFlags:event.modifierFlags
                                                   entered:YES];
    }

    if (_mouseHoverCallbackRef != LUA_NOREF) {
        [self invokeMouseHoverCallbackWithDelay:0.0
                                          since:event.timestamp // NSEvent.timestamp is a value since system startup
                                       location:event.locationInWindow
                                  modifierFlags:event.modifierFlags
                                   flagsChanged:NO];
    }
}

- (void)mouseExited:(NSEvent *)event {
    [self invalidateTimers];

    [self.window close];
    [self.window orderBack:nil];

    if (_mouseExitedCallbackRef != LUA_NOREF) {
        [self invokeMouseEnteredExitedCallbackWithLocation:event.locationInWindow
                                             modifierFlags:event.modifierFlags
                                                   entered:NO];
    }
}

#pragma mark - Handle Modifiers Changes
- (void)flagsChanged:(NSEvent *)event {
    if (_ignoreFlagsChanges) return;

    if (_mouseHoverCallbackRef != LUA_NOREF) {
        if (mouseHoverTimer != nil) {
            [mouseHoverTimer invalidate];
        }
        [self invokeMouseHoverCallbackWithDelay:0.0
                                          since:event.timestamp
                                       location:event.locationInWindow
                                  modifierFlags:event.modifierFlags
                                   flagsChanged:YES];
    }
}

- (void)scrollWheel:(NSEvent *)event {
    NSEventPhase momentumPhase = event.momentumPhase;

    if (_scrollWheelCallbackRef != LUA_NOREF && !(_ignoreMomentumScrolling && momentumPhase != NSEventPhaseNone)) {
        LuaSkin *skin = [LuaSkin shared];
        lua_State *L = skin.L;

        [skin pushLuaRef:refTable ref:_scrollWheelCallbackRef];
        [skin pushLuaRef:refTable ref:_luaRef]; // hotcorner userdata object
        lua_pushnumber(L, event.scrollingDeltaX); // deltaX
        lua_pushnumber(L, event.scrollingDeltaY); // deltaY
        lua_pushinteger(L, event.phase); // phase
        lua_pushinteger(L, momentumPhase); // momntumPhase
        lua_pushinteger(L, (lua_Integer)(event.modifierFlags & NSDeviceIndependentModifierFlagsMask)); // modifierFlags

        if (![skin protectedCallAndTraceback:6 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s \"scrollWheel\" callback error: %s",
                            USERDATA_TAG,
                            lua_tostring(L, -1)]];
            lua_pop(L, 1);
        }
    }
}

@end

#pragma mark - Module Methods

static int hotcorner_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TBREAK];

    NSRect rect = [skin tableToRectAtIndex:1];
    flipRectYCoordinate(&rect);
    HotCornerWindow *window = [[HotCornerWindow alloc] initWithContentRect:rect];

    if (window) {
        HotCornerView *view = [[HotCornerView alloc] initWithFrame:window.contentView.bounds];
        window.contentView = view;

        pushHotCornerWindow(skin.L, window);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

static int hotcorner_show(lua_State *L) {
    HotCornerWindow *window = bridgeToHotCornerWindow(L, 1);
    HotCornerView *view = (HotCornerView *)window.contentView;

    if (view.ignoreFlagsChanges) {
        [window orderFront:nil];
    } else {
        [window makeKeyAndOrderFront:nil];
    }

    lua_pushvalue(L, 1);
    return 1;
}

static int hotcorner_hide(lua_State *L) {
    HotCornerWindow *window = bridgeToHotCornerWindow(L, 1);

    [window close];

    lua_pushvalue(L, 1);
    return 1;
}

static int hotcorner_delete(lua_State *L) {
    void **userdataPointer = (void**)luaL_checkudata(L, 1, USERDATA_TAG);

    if (*userdataPointer != NULL) {
        LuaSkin *skin = [LuaSkin shared];

        HotCornerWindow *window = (__bridge_transfer HotCornerWindow*)*userdataPointer;
        [window close];

        HotCornerView *view = (HotCornerView *)[window contentView];
        [view invalidateTimers];
        view.luaRef = [skin luaUnref:refTable ref:view.luaRef];
        view.mouseUpCallbackRef = [skin luaUnref:refTable ref:view.mouseUpCallbackRef];
        view.mouseDownCallbackRef = [skin luaUnref:refTable ref:view.mouseDownCallbackRef];
        view.mouseEnteredCallbackRef = [skin luaUnref:refTable ref:view.mouseEnteredCallbackRef];
        view.mouseExitedCallbackRef = [skin luaUnref:refTable ref:view.mouseExitedCallbackRef];
        view.mouseClickCallbackRef = [skin luaUnref:refTable ref:view.mouseClickCallbackRef];
        view.mouseHoverCallbackRef = [skin luaUnref:refTable ref:view.mouseHoverCallbackRef];

        window = nil;
        *userdataPointer = NULL;

        lua_pushnil(L);
        lua_setmetatable(L, 1);
    }

    lua_pushnil(L);
    return 1;
}

static int hotcorner_frame(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
     LS_TTABLE | LS_TOPTIONAL,
     LS_TBREAK];

    HotCornerWindow *window = bridgeToHotCornerWindow(L, 1);
    if (lua_istable(L, 2)) {
        NSRect frame = [skin tableToRectAtIndex:2];
        flipRectYCoordinate(&frame);
        [window setFrame:frame display:YES animate:NO];
        lua_pushvalue(L, 1);
    } else {
        NSRect frame = window.frame;
        flipRectYCoordinate(&frame);
        [skin pushNSRect:frame];
    }

    return 1;
}

static int hotcorner_behavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
     LS_TNUMBER | LS_TOPTIONAL,
     LS_TBREAK];

    HotCornerWindow *window = bridgeToHotCornerWindow(L, 1);

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, [window collectionBehavior]);
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
         LS_TNUMBER | LS_TINTEGER,
         LS_TBREAK];

        NSInteger newLevel = lua_tointeger(L, 2);
        @try {
            [window setCollectionBehavior:(NSWindowCollectionBehavior)newLevel];
        }
        @catch ( NSException *theException ) {
            return luaL_error(L, "%s: %s", [[theException name] UTF8String], [[theException reason] UTF8String]);
        }

        lua_pushvalue(L, 1);
    }

    return 1 ;
}

static int hotcorner_maxClickCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
     LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
     LS_TBREAK];

    HotCornerView *view = (HotCornerView *)bridgeToHotCornerWindow(L, 1).contentView;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, view.maxClickCount);
    } else {
        lua_Integer newMaxClickCount = lua_tointeger(L, 2);
        view.maxClickCount = newMaxClickCount;
        lua_pushvalue(L, 1);
    }

    return 1;
}

static int hotcorner_multiClickInterval(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
     LS_TNUMBER | LS_TOPTIONAL,
     LS_TBREAK];

    HotCornerView *view = (HotCornerView *)bridgeToHotCornerWindow(L, 1).contentView;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, view.multiClickInterval);
    } else {
        NSTimeInterval newMultiClickInterval = lua_tonumber(L, 2);
        view.multiClickInterval = newMultiClickInterval;
        lua_pushvalue(L, 1);
    }

    return 1;
}

static int hotcorner_ignoreFlagsChanges(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
     LS_TBOOLEAN | LS_TOPTIONAL,
     LS_TBREAK];

    HotCornerView *view = (HotCornerView *)bridgeToHotCornerWindow(L, 1).contentView;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.ignoreFlagsChanges);
    } else {
        BOOL ignore = (BOOL)lua_toboolean(L, 2);
        view.ignoreFlagsChanges = ignore;
        lua_pushvalue(L, 1);
    }

    return 1;
}

static int hotcorner_ignoreMomentumScrolling(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
     LS_TBOOLEAN | LS_TOPTIONAL,
     LS_TBREAK];

    HotCornerView *view = (HotCornerView *)bridgeToHotCornerWindow(L, 1).contentView;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.ignoreMomentumScrolling);
    } else {
        BOOL ignore = (BOOL)lua_toboolean(L, 2);
        view.ignoreMomentumScrolling = ignore;
        lua_pushvalue(L, 1);
    }

    return 1;
}

static int hotcorner_debugColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
     LS_TTABLE | LS_TNIL | LS_TOPTIONAL,
     LS_TBREAK];

    HotCornerWindow *window = bridgeToHotCornerWindow(L, 1);

    int type = lua_type(L, 2);
    if (type == LUA_TTABLE) {
        window.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"];
        window.opaque = YES;
        lua_pushvalue(L, 1);
    } else if(type == LUA_TNIL) {
        window.backgroundColor = [NSColor clearColor];
        window.opaque = NO;
    } else {
        [skin pushNSObject:[window backgroundColor]];
    }

    return 1;
}

#define callbackFunctionBody(refName) LuaSkin *skin = [LuaSkin shared]; \
[skin checkArgs:LS_TUSERDATA, USERDATA_TAG, \
                LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, \
                LS_TBREAK]; \
HotCornerView *view = (HotCornerView *)bridgeToHotCornerWindow(L, 1).contentView; \
int type = lua_type(L, 2); \
if (type == LUA_TFUNCTION) { \
    view.refName = [skin luaRef:refTable atIndex:2]; \
} else if (type == LUA_TNIL) { \
    view.refName = [skin luaUnref:refTable ref:view.refName]; \
} else if (view.refName == LUA_NOREF || view.refName == LUA_REFNIL) { \
    lua_pushnil(L); \
    return 1; \
} else { \
    [skin pushLuaRef:refTable ref:view.refName]; \
    return 1; \
} \
lua_settop(L, 1); \
return 1;

static int hotcorner_mouseUpCallback(lua_State *L) {
    callbackFunctionBody(mouseUpCallbackRef)
}

static int hotcorner_mouseDownCallback(lua_State *L) {
    callbackFunctionBody(mouseDownCallbackRef)
}

static int hotcorner_mouseEnteredCallback(lua_State *L) {
    callbackFunctionBody(mouseEnteredCallbackRef)
}

static int hotcorner_mouseExitedCallback(lua_State *L) {
    callbackFunctionBody(mouseExitedCallbackRef)
}

static int hotcorner_mouseClickCallback(lua_State *L) {
    callbackFunctionBody(mouseClickCallbackRef)
}

static int hotcorner_mouseHoverCallback(lua_State *L) {
    callbackFunctionBody(mouseHoverCallbackRef)
}

static int hotcorner_scrollWheelCallback(lua_State *L) {
    callbackFunctionBody(scrollWheelCallbackRef)
}

#pragma mark Module Constants & Lua Infrastructure

static int pushModifierFlags(lua_State *L) {
    lua_newtable(L);
    lua_pushinteger(L, NSEventModifierFlagCapsLock);                    lua_setfield(L, -2, "capsLock");
    lua_pushinteger(L, NSEventModifierFlagCapsLock);                    lua_setfield(L, -2, "capslock");
    lua_pushinteger(L, NSEventModifierFlagCommand);                     lua_setfield(L, -2, "command");
    lua_pushinteger(L, NSEventModifierFlagCommand);                     lua_setfield(L, -2, "cmd");
    lua_pushinteger(L, NSEventModifierFlagControl);                     lua_setfield(L, -2, "control");
    lua_pushinteger(L, NSEventModifierFlagControl);                     lua_setfield(L, -2, "ctrl");
    lua_pushinteger(L, NSEventModifierFlagFunction);                    lua_setfield(L, -2, "function");
    lua_pushinteger(L, NSEventModifierFlagFunction);                    lua_setfield(L, -2, "fn");
    lua_pushinteger(L, NSEventModifierFlagHelp);                        lua_setfield(L, -2, "help");
    lua_pushinteger(L, NSEventModifierFlagNumericPad);                  lua_setfield(L, -2, "numericPad");
    lua_pushinteger(L, NSEventModifierFlagOption);                      lua_setfield(L, -2, "option");
    lua_pushinteger(L, NSEventModifierFlagOption);                      lua_setfield(L, -2, "opt");
    lua_pushinteger(L, NSEventModifierFlagOption);                      lua_setfield(L, -2, "alt");
    lua_pushinteger(L, NSEventModifierFlagShift);                       lua_setfield(L, -2, "shift");
    lua_pushinteger(L, NSEventModifierFlagCommand);                     lua_setfield(L, -2, "⌘");
    lua_pushinteger(L, NSEventModifierFlagShift);                       lua_setfield(L, -2, "⇧");
    lua_pushinteger(L, NSEventModifierFlagControl);                     lua_setfield(L, -2, "⌃");
    lua_pushinteger(L, NSEventModifierFlagOption);                      lua_setfield(L, -2, "⌥");
    return 1;
}

static int pushEventPhases(lua_State *L) {
    lua_newtable(L);
    lua_pushinteger(L, NSEventPhaseNone);                               lua_setfield(L, -2, "none");
    lua_pushinteger(L, NSEventPhaseBegan);                              lua_setfield(L, -2, "began");
    lua_pushinteger(L, NSEventPhaseEnded);                              lua_setfield(L, -2, "ended");
    lua_pushinteger(L, NSEventPhaseChanged);                            lua_setfield(L, -2, "changed");
    lua_pushinteger(L, NSEventPhaseMayBegin);                           lua_setfield(L, -2, "mayBegin");
    lua_pushinteger(L, NSEventPhaseCancelled);                          lua_setfield(L, -2, "cancelled");
    lua_pushinteger(L, NSEventPhaseStationary);                         lua_setfield(L, -2, "stationary");
    return 1;
}

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]);
    return 1 ;
}

static const luaL_Reg userdata_metaLib[] = {
    {"show",                    hotcorner_show},
    {"hide",                    hotcorner_hide},
    {"delete",                  hotcorner_delete},
    {"frame",                   hotcorner_frame},
    {"behavior",                hotcorner_behavior},
    {"maxClickCount",           hotcorner_maxClickCount},
    {"multiClickInterval",      hotcorner_multiClickInterval},
    {"ignoreFlagsChanges",      hotcorner_ignoreFlagsChanges},
    {"ignoreMomentumScrolling", hotcorner_ignoreMomentumScrolling},
    {"debugColor",              hotcorner_debugColor},
    {"mouseUpCallback",         hotcorner_mouseUpCallback},
    {"mouseDownCallback",       hotcorner_mouseDownCallback},
    {"mouseEnteredCallback",    hotcorner_mouseEnteredCallback},
    {"mouseExitedCallback",     hotcorner_mouseExitedCallback},
    {"mouseClickCallback",      hotcorner_mouseClickCallback},
    {"mouseHoverCallback",      hotcorner_mouseHoverCallback},
    {"scrollWheelCallback",     hotcorner_scrollWheelCallback},
    {"__tostring",              userdata_tostring},
    {"__gc",                    hotcorner_delete},
    {NULL,                      NULL}
};

static luaL_Reg moduleLib[] = {
    {"new",                     hotcorner_new},
    {NULL,                      NULL}
};

int luaopen_hotcorner_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    pushModifierFlags(L);               lua_setfield(L, -2, "modifierFlags");
    pushEventPhases(L);                 lua_setfield(L, -2, "eventPhases");
    return 1;
}
