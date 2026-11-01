#import <AppKit/AppKit.h>
#import <GameController/GameController.h>
#import <QuartzCore/QuartzCore.h>
#import "Assets.h"
#include "system.h"
#include "Vigasoco.h"
#include "Juego.h"
#include "Pergamino.h"
#include "Logica.h"
#include "Personaje.h"
#include "../../Tests/RouteBoundaryRegression.h"
#include <unistd.h>
#include <algorithm>
#include <set>
#include <cstdio>

#import "Presentation.h"
static CGImageRef FrameImage() { return CreateGameImage(); }
static bool WriteFrame(NSString *path) {
    CGImageRef image = FrameImage();
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
    CGImageRelease(image);
    return [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

@class AppDelegate;
@interface GameView : NSView
@property(nonatomic, weak) AppDelegate *owner;
@property(nonatomic) BOOL ready;
@property(nonatomic) BOOL paused;
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation> {
    Vigasoco *_engine;
    std::set<unsigned short> _keys;
    std::set<unsigned short> _pressed;
    CFTimeInterval _lastTick;
    bool _controllerAcceptDown;
}
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) GameView *gameView;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSButton *importButton;
@property(nonatomic) BOOL paused;
- (void)setKey:(unsigned short)key down:(BOOL)down;
- (void)importData:(id)sender;
- (void)gameMenu:(id)sender;
- (void)togglePause:(id)sender;
@end

@implementation GameView
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)isFlipped { return YES; }
- (void)keyDown:(NSEvent *)event {
    if (event.isARepeat && (event.keyCode == 36 || event.keyCode == 19)) return;
    if (event.modifierFlags & NSEventModifierFlagCommand) { [super keyDown:event]; return; }
    if (event.keyCode == 53) { if (!event.isARepeat) [self.owner gameMenu:nil]; return; }
    if (event.keyCode == 35) { if (!event.isARepeat) [self.owner togglePause:nil]; return; }
    [self.owner setKey:event.keyCode down:YES];
}
- (void)keyUp:(NSEvent *)event { [self.owner setKey:event.keyCode down:NO]; }
- (void)mouseDown:(NSEvent *)event { [self.window makeFirstResponder:self]; }
- (void)drawRect:(NSRect)dirty {
    if (self.ready) {
        [NSColor.blackColor setFill]; NSRectFill(self.bounds);
        CGFloat scale = MIN(self.bounds.size.width/640.0,self.bounds.size.height/400.0);
        // Align the destination to backing pixels and preserve the original 8:5 frame.
        NSRect rect = NSMakeRect((self.bounds.size.width-640*scale)/2, (self.bounds.size.height-400*scale)/2, 640*scale, 400*scale);
        rect = [self backingAlignedRect:rect options:NSAlignAllEdgesNearest];
        CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
        CGContextSaveGState(ctx);
        CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
        CGContextTranslateCTM(ctx, rect.origin.x, NSMaxY(rect));
        CGContextScaleCTM(ctx, 1, -1);
        CGImageRef image = FrameImage();
        CGContextDrawImage(ctx, CGRectMake(0,0,rect.size.width,rect.size.height), image);
        CGImageRelease(image); CGContextRestoreGState(ctx);
        if (self.paused) {
            [[NSColor colorWithWhite:0 alpha:0.62] setFill];
            NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
            NSRect card = NSMakeRect((self.bounds.size.width-320)/2,(self.bounds.size.height-150)/2,320,150);
            [[NSColor colorWithRed:0.075 green:0.095 blue:0.085 alpha:0.96] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:card xRadius:16 yRadius:16] fill];
            [[NSColor colorWithRed:0.72 green:0.61 blue:0.40 alpha:0.5] setStroke];
            [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(card,0.5,0.5) xRadius:16 yRadius:16] stroke];
            [self text:@"THE ABBEY WAITS" y:self.bounds.size.height/2-48 size:10 color:[NSColor colorWithRed:0.80 green:0.70 blue:0.49 alpha:1] serif:NO];
            [self text:@"Paused" y:self.bounds.size.height/2-22 size:34 color:NSColor.whiteColor serif:YES];
            [self text:@"Press P or ⌘P to continue" y:self.bounds.size.height/2+30 size:12 color:NSColor.lightGrayColor serif:NO];
        }
        return;
    }
    [[NSColor colorWithRed:0.94 green:0.92 blue:0.87 alpha:1] setFill]; NSRectFill(self.bounds);
    CGFloat x = self.bounds.size.width/2, y = MAX(42, self.bounds.size.height/2-190);
    NSColor *ink = [NSColor colorWithRed:0.18 green:0.22 blue:0.20 alpha:1];
    [ink setStroke];
    for (int i = 0; i < 3; ++i) {
        CGFloat w = 72-i*16, h = 108-i*13;
        NSBezierPath *arch = [NSBezierPath bezierPath];
        [arch moveToPoint:NSMakePoint(x-w/2,y+108)];
        [arch lineToPoint:NSMakePoint(x-w/2,y+108-h+30)];
        [arch curveToPoint:NSMakePoint(x,y+108-h) controlPoint1:NSMakePoint(x-w/2,y+108-h+12) controlPoint2:NSMakePoint(x-8,y+108-h+3)];
        [arch curveToPoint:NSMakePoint(x+w/2,y+108-h+30) controlPoint1:NSMakePoint(x+8,y+108-h+3) controlPoint2:NSMakePoint(x+w/2,y+108-h+12)];
        [arch lineToPoint:NSMakePoint(x+w/2,y+108)]; arch.lineWidth = 2; [arch stroke];
    }
    [self text:@"LA ABADÍA DEL CRIMEN" y:y+140 size:31 color:ink serif:YES];
    [self text:@"A mystery in seven days." y:y+187 size:17 color:ink serif:YES];
    [self text:@"Required: abadia.dsk · GraficosCPC · GraficosVGA" y:y+222 size:13 color:ink serif:NO];
    [self text:@"Select your Abbey folder. Audio files are optional." y:y+244 size:13 color:ink serif:NO];
    [self text:@"Paco Menéndez · Juan Delcán · 1987" y:self.bounds.size.height-54 size:12 color:ink serif:NO];
    [self text:@"Native macOS port · VIGASOCO / Abbey" y:self.bounds.size.height-33 size:11 color:ink serif:NO];
}
- (void)text:(NSString *)text y:(CGFloat)y size:(CGFloat)size color:(NSColor *)color serif:(BOOL)serif {
    NSFont *font = serif ? [NSFont fontWithName:@"Baskerville" size:size] : [NSFont systemFontOfSize:size];
    NSDictionary *style = @{NSFontAttributeName:font ?: [NSFont systemFontOfSize:size], NSForegroundColorAttributeName:color};
    CGFloat width = [text sizeWithAttributes:style].width;
    [text drawAtPoint:NSMakePoint((self.bounds.size.width-width)/2,y) withAttributes:style];
}
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self createMenus];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,960,600)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"La abadía del crimen";
    self.window.minSize = NSMakeSize(640,440);
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    self.window.delegate = self;
    self.window.releasedWhenClosed = NO;
    self.window.frameAutosaveName = @"AbadiaMainWindow";
    self.gameView = [[GameView alloc] initWithFrame:NSMakeRect(0,0,960,600)];
    self.gameView.owner = self;
    self.gameView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    [self.gameView setAccessibilityLabel:@"La abadía del crimen game screen"];
    self.window.contentView = self.gameView;
    self.importButton = [NSButton buttonWithTitle:@"Import Game Data…" target:self action:@selector(importData:)];
    self.importButton.bezelStyle = NSBezelStyleRounded;
    self.importButton.controlSize = NSControlSizeLarge;
    self.importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.gameView addSubview:self.importButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.importButton.centerXAnchor constraintEqualToAnchor:self.gameView.centerXAnchor],
        [self.importButton.centerYAnchor constraintEqualToAnchor:self.gameView.centerYAnchor constant:115]
    ]];
    [self.window center]; [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.gameView];
    [NSApp activateIgnoringOtherApps:YES];
    NSURL *support = AbadiaSupportDirectory();
    NSURL *data = [support URLByAppendingPathComponent:@"roms/abadia"];
    if (!ValidateAssets(data)) [self startEngine:support];
    self.timer = [NSTimer timerWithTimeInterval:1.0/60 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}
- (void)createMenus {
    NSMenu *bar = [NSMenu new]; NSApp.mainMenu = bar;
    NSMenu *(^submenu)(NSString *) = ^NSMenu *(NSString *name) {
        NSMenuItem *item = [bar addItemWithTitle:name action:nil keyEquivalent:@""];
        item.submenu = [[NSMenu alloc] initWithTitle:name]; return item.submenu;
    };
    void (^add)(NSMenu *, NSString *, SEL, NSString *) = ^(NSMenu *menu, NSString *title, SEL action, NSString *key) {
        NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:key]; item.target = self;
    };
    NSMenu *app = submenu(@"Abadía");
    add(app,@"About La abadía del crimen",@selector(about:),@"");
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:@"Hide Abadía" action:@selector(hide:) keyEquivalent:@"h"];
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:@"Quit Abadía" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenu *file = submenu(@"File");
    add(file,@"Import Game Data…",@selector(importData:),@"o");
    add(file,@"Show Saves in Finder",@selector(showSaves:),@"");
    add(file,@"Save Screenshot…",@selector(screenshot:),@"s");
    NSMenu *game = submenu(@"Game");
    add(game,@"Game Menu",@selector(gameMenu:),@"m");
    add(game,@"Pause",@selector(togglePause:),@"p");
    add(game,@"Mute Audio",@selector(toggleMute:),@"u");
    NSMenu *view = submenu(@"View");
    NSMenuItem *fullscreen = [view addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
    fullscreen.keyEquivalentModifierMask = NSEventModifierFlagCommand|NSEventModifierFlagControl;
    add(view,@"Original Size",@selector(originalSize:),@"1");
    add(view,@"Double Size",@selector(doubleSize:),@"2");
    NSMenu *help = submenu(@"Help");
    add(help,@"Getting Started…",@selector(gettingStarted:),@"");
    add(help,@"How to Play",@selector(help:),@"?");
    NSApp.helpMenu = help;
}
- (void)startEngine:(NSURL *)support {
    if (_engine) return;
    if (chdir(support.fileSystemRepresentation) != 0) { [self alert:@"Unable to open the save folder." detail:support.path]; return; }
    _engine = new Vigasoco();
    if (!_engine->init()) { delete _engine; _engine = nullptr; [self alert:@"Unable to initialize the game." detail:@"Reimport the supported Abbey game data and relaunch."]; return; }
    self.gameView.ready = YES; self.importButton.hidden = YES;
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"HasSeenWelcome"]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self gettingStarted:nil]; });
    }
    [self.window makeFirstResponder:self.gameView];
    _engine->mainLoop(); self.gameView.needsDisplay = YES;
}
- (void)importData:(id)sender {
    if (_engine) { [self alert:@"Game data is already installed." detail:@"Your data and saves are in ~/Library/Application Support/Abadia. Quit the app before replacing data."]; return; }
    NSOpenPanel *panel = NSOpenPanel.openPanel;
    panel.canChooseFiles = NO; panel.canChooseDirectories = YES;
    panel.prompt = @"Import";
    panel.message = @"Select your Abbey folder or its roms/abadia folder. Required: abadia.dsk, GraficosCPC, GraficosVGA. Optional: WAV audio. Your original files stay in place.";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) return;
        NSError *error = nil;
        NSURL *support = AbadiaSupportDirectory();
        NSURL *folder = FindAssetDirectory(panel.URL) ?: panel.URL;
        if (!ImportAssets(folder, support, &error)) [self alert:@"Could not import game data" detail:error.localizedDescription];
        else [self startEngine:support];
    }];
}
- (void)setKey:(unsigned short)key down:(BOOL)down {
    if (down) { _keys.insert(key); _pressed.insert(key); }
    else _keys.erase(key);
}
- (void)tick:(NSTimer *)timer {
    if (!_engine || !self.gameView.ready || self.paused || !NSApp.isActive || self.window.attachedSheet) return;
    CFTimeInterval now = CACurrentMediaTime();
    if (now-_lastTick < sys->minimumFrameTime/1000.0) return;
    _lastTick = now;
    auto key = [&](int k) { return _keys.count(k) > 0 || _pressed.count(k) > 0; };
    sys->pad = {key(126)||key(13),key(125)||key(1),key(123)||key(0),key(124)||key(2),key(49),key(45)||key(8),_pressed.count(36)>0,key(6),_pressed.count(19)>0};
    _pressed.clear();
    GCExtendedGamepad *pad = GCController.controllers.firstObject.extendedGamepad;
    if (pad) {
        sys->pad.up |= pad.dpad.up.pressed || pad.leftThumbstick.yAxis.value > 0.5;
        sys->pad.down |= pad.dpad.down.pressed || pad.leftThumbstick.yAxis.value < -0.5;
        sys->pad.left |= pad.dpad.left.pressed || pad.leftThumbstick.xAxis.value < -0.5;
        sys->pad.right |= pad.dpad.right.pressed || pad.leftThumbstick.xAxis.value > 0.5;
        sys->pad.button3 |= pad.buttonA.pressed && !_controllerAcceptDown;
        _controllerAcceptDown = pad.buttonA.pressed;
        sys->pad.button2 |= pad.buttonB.pressed;
        sys->pad.button1 |= pad.buttonX.pressed;
        sys->pad.button4 |= pad.buttonY.pressed;
        static bool menuWasDown = false;
        bool menuDown = pad.buttonMenu.pressed;
        if (menuDown && !menuWasDown) [self gameMenu:nil];
        menuWasDown = menuDown;
    }
    if (sys->pad.start) { [self gameMenu:nil]; _keys.erase(19); }
    _engine->mainLoop(); self.gameView.needsDisplay = YES;
    if (!sys->pendingError.empty()) {
        NSString *message = @(sys->pendingError.c_str()); sys->pendingError.clear();
        _keys.clear(); _pressed.clear();
        [self alert:@"Progress could not be updated" detail:message];
    }
    if (sys->exit) [NSApp terminate:nil];
}
- (void)gameMenu:(id)sender {
    if (!_engine || !self.gameView.ready) return;
    self.paused = NO; self.gameView.paused = NO;
    _keys.clear(); _pressed.clear(); sys->pad = {}; sys->setAudioPaused(false);
    _engine->changeState(MENU);
    _engine->mainLoop(); self.gameView.needsDisplay = YES;
}
- (void)togglePause:(id)sender {
    if (!self.gameView.ready) return;
    self.paused = !self.paused; self.gameView.paused = self.paused;
    _keys.clear(); _pressed.clear(); sys->pad = {}; sys->setAudioPaused(self.paused); self.gameView.needsDisplay = YES;
}
- (void)toggleMute:(NSMenuItem *)sender { sys->muted = !sys->muted; if (sys->muted) sys->stopMusic(); }
- (void)applicationDidResignActive:(NSNotification *)note {
    _keys.clear(); _pressed.clear(); sys->pad = {};
    if (self.gameView.ready && !self.paused) [self togglePause:nil];
}
- (void)windowDidResignKey:(NSNotification *)note { _keys.clear(); _pressed.clear(); sys->pad = {}; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
- (void)applicationWillTerminate:(NSNotification *)notification { [self.timer invalidate]; sys->stopMusic(); }
- (void)showSaves:(id)sender { [NSWorkspace.sharedWorkspace openURL:AbadiaSupportDirectory()]; }
- (void)originalSize:(id)sender { [self.window setContentSize:NSMakeSize(640,400)]; }
- (void)doubleSize:(id)sender { [self.window setContentSize:NSMakeSize(1280,800)]; }
- (void)screenshot:(id)sender {
    if (!self.gameView.ready) return;
    BOOL wasPaused = self.paused; self.paused = YES;
    _keys.clear(); _pressed.clear(); sys->pad = {};
    if (!wasPaused) sys->setAudioPaused(true);
    NSSavePanel *panel = NSSavePanel.savePanel; panel.nameFieldStringValue = @"Abadia.png";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && !WriteFrame(panel.URL.path)) [self alert:@"Could not save the screenshot" detail:@"Choose a writable location."];
        self.paused = wasPaused;
        self->_keys.clear(); self->_pressed.clear(); sys->pad = {};
        if (!wasPaused) sys->setAudioPaused(false);
    }];
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(togglePause:)) { item.title = self.paused ? @"Resume" : @"Pause"; return self.gameView.ready; }
    if (item.action == @selector(toggleMute:)) item.state = sys->muted ? NSControlStateValueOn : NSControlStateValueOff;
    if (item.action == @selector(gameMenu:) || item.action == @selector(screenshot:) || item.action == @selector(showSaves:)) return self.gameView.ready;
    return YES;
}
- (void)alert:(NSString *)title detail:(NSString *)detail {
    NSAlert *alert = [NSAlert new]; alert.messageText = title; alert.informativeText = detail;
    _keys.clear(); _pressed.clear(); sys->pad = {};
    if (!self.paused) sys->setAudioPaused(true);
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        self->_keys.clear(); self->_pressed.clear(); sys->pad = {};
        if (!self.paused) sys->setAudioPaused(false);
        [self.window makeFirstResponder:self.gameView];
    }];
}
- (void)about:(id)sender {
    [self alert:@"La abadía del crimen · 0.2.1" detail:@"Original game: Paco Menéndez and Juan Delcán (1987).\nC++ reconstruction: Manuel Abadía / VIGASOCO.\nSDL adaptation: Luzbel. Graphics: Antonio Giner.\nAbbey: Samuel Salinas Almaguer and contributors.\nNative macOS port: pballada.\n\nA noncommercial preservation project. Original assets are imported separately. See README and VIGASOCO.txt for attribution and terms."];
}
- (void)gettingStarted:(id)sender {
    NSAlert *guide = [NSAlert new];
    guide.messageText = self.gameView.ready ? @"Welcome to the abbey" : @"Bring your game data";
    guide.informativeText = self.gameView.ready
        ? @"1. Press Return on the title, then choose New Game. Return also skips the prologue.\n\n2. Walk forward with ↑ or W. Turn with ← → or A D. These are character-relative controls.\n\n3. Follow the abbot when you arrive. Attend services and meals, and keep an eye on obsequium.\n\nEscape opens the game menu. Save regularly in its seven slots. P pauses; switching apps pauses automatically.\n\nYou can reopen this guide from Help → Getting Started."
        : @"You need three files from the supported Abbey data pack:\n\n• abadia.dsk\n• GraficosCPC\n• GraficosVGA\n\nChoose the Abbey folder, build folder, or roms/abadia folder with Import Game Data. The app finds the files inside. WAV audio is optional.\n\nThe app copies the data to Application Support and leaves your source files in place. A disk image alone is not enough.";
    [guide addButtonWithTitle:self.gameView.ready ? @"Enter the Abbey" : @"Got It"];
    _keys.clear(); _pressed.clear(); sys->pad = {};
    if (!self.paused) sys->setAudioPaused(true);
    [guide beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (self.gameView.ready) [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"HasSeenWelcome"];
        self->_keys.clear(); self->_pressed.clear(); sys->pad = {};
        if (!self.paused) sys->setAudioPaused(false);
        [self.window makeFirstResponder:self.gameView];
    }];
}
- (void)help:(id)sender {
    [self alert:@"Enter the abbey" detail:@"Return: accept / skip the introduction\n↑ or W: walk forward\n← → or A D: turn\n↓ or S: command Adso (as in the original)\nSpace: drop an object\nN or C: no / secondary action\nZ: alternate action\nEsc or ⌘M: game menu (new game, seven save slots, load, language, continue)\nP or ⌘P: pause\n⌃⌘F: fullscreen · ⌘U: mute\n\nControllers: D-pad / left stick, A to accept, B for no, X to drop, Y for alternate action, Menu to open the game menu.\n\nFollow the abbot on arrival. Observe the abbey’s daily schedule and protect your obsequium. The game pauses when you switch apps."];
}
@end

static int SmokeTest(NSString *source, NSString *output) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *temp = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    NSError *error = nil;
    NSURL *sourceURL = [NSURL fileURLWithPath:source];
    NSURL *parent = sourceURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent;
    if (!FindAssetDirectory(sourceURL) || !FindAssetDirectory(parent)) {
        fprintf(stderr,"FAIL data folder discovery\n"); return 1;
    }
    printf("PASS importer discovers data inside the selected parent folder\n");
    if (!ImportAssets(sourceURL, temp, &error)) { fprintf(stderr,"%s\n",error.localizedDescription.UTF8String); return 1; }
    NSString *cwd = fm.currentDirectoryPath;
    if (chdir(temp.fileSystemRepresentation)) return 1;
    sys->muted = true;
    Vigasoco engine;
    if (!engine.init()) return 1;
    auto tick = [&]() { engine.mainLoop(); sys->pad = {}; };
    auto check = [](bool ok, const char *message) { printf("%s %s\n",ok?"PASS":"FAIL",message); return ok; };
    bool ok = true;
    tick();
    ok &= check(Abadia::elJuego->currentState == INTRO,"intro initializes");
    sys->pad.button3 = true; tick();
    ok &= check(Abadia::elJuego->currentState == MENU,"Return opens menu");
    sys->pad.button3 = true; tick();
    ok &= check(Abadia::elJuego->currentState == SCROLL,"new game enters prologue");
    for (int i=0; i<12; ++i) tick();
    sys->pad.button3 = true; tick();
    for (int i=0; i<100 && Abadia::elJuego->currentState != PLAY; ++i) { sys->pad.button3 = true; tick(); }
    ok &= check(Abadia::elJuego->currentState == PLAY,"prologue can be skipped into gameplay");
    auto *game = Abadia::elJuego;
    int facing = game->personajes[0]->orientacion;
    sys->pad.left = true; tick();
    ok &= check(game->personajes[0]->orientacion != facing,"player responds to turn input");
    for (int i=0;i<120;++i) tick();
    ok &= check(std::any_of(sys->framebuffer.begin(),sys->framebuffer.end(),[](uint32_t n){return (n&0xffffff)!=0;}),"game produces visible pixels");
    if (output) ok &= check(WriteFrame(output),"gameplay screenshot written");
    int savedX=game->personajes[0]->posX, savedY=game->personajes[0]->posY;
    engine.changeState(MENU); game->seleccionado=2; sys->pad.button3=true; tick();
    game->seleccionado=0; sys->pad.button3=true; tick();
    ok &= check([fm attributesOfItemAtPath:@"abadia0.save" error:nil].fileSize>0,"save slot writes a real game state");
    game->personajes[0]->posX = savedX + 3;
    game->personajes[0]->posY = savedY + 2;
    engine.changeState(MENU); game->seleccionado=1; sys->pad.button3=true; tick();
    game->seleccionado=0; sys->pad.button3=true; tick();
    ok &= check(game->currentState == ASK_CONTINUE,"loading asks before replacing the current game");
    game->seleccionado=0; sys->pad.button3=true; tick();
    ok &= check(game->personajes[0]->posX==savedX && game->personajes[0]->posY==savedY,"save slot restores player position");
    // Empty and corrupt slots must never reset a running game.
    auto attemptLoad = [&](int slot) {
        engine.changeState(MENU); game->seleccionado=1; sys->pad.button3=true; tick();
        game->seleccionado=slot; sys->pad.button3=true; tick();
        game->seleccionado=0; sys->pad.button3=true; tick();
    };
    int beforeX=game->personajes[0]->posX, beforeY=game->personajes[0]->posY;
    attemptLoad(6);
    ok &= check(game->currentState==LOAD && game->personajes[0]->posX==beforeX && game->personajes[0]->posY==beforeY && !sys->pendingError.empty(),"empty slot preserves live progress and reports failure");
    sys->pendingError.clear();
    NSData *goodSave=[NSData dataWithContentsOfFile:@"abadia0.save"];
    NSMutableData *badSave=[goodSave mutableCopy];
    ((unsigned char *)badSave.mutableBytes)[0]^=1;
    [badSave writeToFile:@"abadia0.save" atomically:YES];
    attemptLoad(0);
    ok &= check(game->personajes[0]->posX==beforeX && game->personajes[0]->posY==beforeY && !sys->pendingError.empty(),"corrupt save is rejected before mutating the live world");
    sys->pendingError.clear();
    [goodSave writeToFile:@"abadia0.save" atomically:YES];
    [fm createDirectoryAtPath:@"abadia0.save.tmp" withIntermediateDirectories:NO attributes:nil error:nil];
    engine.changeState(MENU); game->seleccionado=2; sys->pad.button3=true; tick();
    game->seleccionado=0; sys->pad.button3=true; tick();
    ok &= check(game->currentState==SAVE && [[NSData dataWithContentsOfFile:@"abadia0.save"] isEqual:goodSave] && !sys->pendingError.empty(),"failed overwrite keeps the old slot and stays in save menu");
    [fm removeItemAtPath:@"abadia0.save.tmp" error:nil]; sys->pendingError.clear();
    for (int slot=0;slot<7;++slot) {
        engine.changeState(MENU); game->seleccionado=2; sys->pad.button3=true; tick();
        game->seleccionado=slot; sys->pad.button3=true; tick();
        ok &= check(sys->validateSave(std::string("abadia")+std::to_string(slot)+".save"),"save slot has a valid integrity footer");
        game->personajes[0]->posX=beforeX+3;
        attemptLoad(slot);
        ok &= check(game->currentState==PLAY && game->personajes[0]->posX==beforeX,"slot restores saved world after player position changes");
    }
    for (int i=0;i<500;++i) tick();
    ok &= check(true,"500 additional game ticks complete");
    ok &= check(Abadia::RouteBoundaryRegression::run(),"screen-exit path planning preserves character state and avoids abort");
    chdir(cwd.fileSystemRepresentation); [fm removeItemAtURL:temp error:nil];
    return ok?0:1;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc>1 && std::string(argv[1])=="--self-test") return RunSelfTests();
        if (argc>2 && std::string(argv[1])=="--smoke-test")
            return SmokeTest(@(argv[2]),argc>3?@(argv[3]):nil);
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        AppDelegate *delegate = [AppDelegate new]; NSApp.delegate=delegate;
        [NSApp run];
    }
    return 0;
}
