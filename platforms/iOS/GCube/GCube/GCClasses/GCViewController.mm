/*
 * The MIT License (MIT)
 * Copyright (c) 2011 GClue, inc.
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

//
//  AEViewController.m
//  AizuEngine
//
//  Created by Takashi Tsuchiya on 11/10/14.
//  Copyright (c) 2011年 GClue, inc. All rights reserved.
//

#pragma mark - APIGlue

#include "ApplicationController.h"
#include "APIGlue.h"
#include "Figure.h"
#include "Texture.h"
#include "main.h"

#import "PVRTexture.h"

// コントローラーインスタンス
static ApplicationController *controller = NULL;

/**
 * インスタンスを返します.
 * @return インスタンス
 */
ApplicationController* CGControllerInstance() {
	return controller;
}

/**
 * リソースファイルを読み込みます.
 * @param[in] fileName ファイル名
 * @return charのvectorオブジェクト
 */
std::vector<char>* GCLoadAsset(const char *fileName) {
	LOGD("GCLoadAsset: %s", fileName);
    NSString *fname = [NSString stringWithCString:fileName encoding:NSUTF8StringEncoding];
	NSString *path;
	if ([[NSFileManager defaultManager] fileExistsAtPath:fname]){
		// ファイルが存在したら絶対パス
		path = fname;
	} else {
		// 相対パスの場合はリソースから
		path = [[NSBundle mainBundle] pathForResource:[fname lastPathComponent] ofType:nil];
	}
	NSData *data = [NSData dataWithContentsOfFile:path];
	const char *buffer = (const char*)[data bytes];
	std::vector<char> *outbuf = new std::vector<char>(buffer, buffer + [data length]);
    return outbuf;
}

/**
 * テクスチャを読み込みます.
 * @param[in] fileName ファイル名
 * @return テクスチャオブジェクト
 */
bool GCLoadTexture(Texture *texture, const char *fileName) {
	LOGD("GCLoadTexture: %s", fileName);
    
    // 画像読み込み
    NSString *fname = [NSString stringWithCString:fileName encoding:NSUTF8StringEncoding];
	UIImage *uimg = nil;
	if ([[NSFileManager defaultManager] fileExistsAtPath:fname]){
		// ファイルが存在したら絶対パス
		uimg = [[UIImage alloc] initWithContentsOfFile:fname];
	} else {
		// pvrが存在する時はそちらが優先
		NSString *pvrname = [[fname stringByDeletingPathExtension] stringByAppendingPathExtension:@"pvr"];
		NSString *pvrpath = [[NSBundle mainBundle] pathForResource:[pvrname lastPathComponent] ofType:nil];
		if ([[NSFileManager defaultManager] fileExistsAtPath:pvrpath]){
			PVRTexture *pvr = [[PVRTexture alloc] initWithContentsOfFile:pvrpath];
			if (pvr) {
				LOGD("*use pvr*");
				texture->texName = [pvr name];
				texture->width = [pvr width];
				texture->height = [pvr height];
				[pvr release];
				return true;
			}
		}
		// 相対パスの場合はリソースから
		NSString *fpath = [[NSBundle mainBundle] pathForResource:[fname lastPathComponent] ofType:nil];
		uimg = [[UIImage alloc] initWithContentsOfFile:fpath];
	}
	if (!uimg) {
		LOGE("**********ERROR(GCLoadTexture)**************");
		exit(1);
	}
	CGImageRef img = [uimg CGImage];
    
    CGContextRef	texContext;
    GLubyte			*texData;
    
    // サイズ取得
    size_t width = CGImageGetWidth(img);
    size_t height = CGImageGetHeight(img);
    
    // メモリ確保
    texData = (GLubyte *) malloc(width * height * 4);
    // texDataに対応したBitmapContext作成
    texContext = CGBitmapContextCreate(texData, width, height, 8, width * 4, CGImageGetColorSpace(img), kCGImageAlphaPremultipliedLast);
    // Context(texData)に描画
    CGRect rect = CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height);
    CGContextClearRect(texContext, rect);
    CGContextDrawImage(texContext, rect, img);
    // Contextはもう要らないので解放
    CGContextRelease(texContext);
	
	// テクスチャ作成
	texture->setImageData(texData, width, height);
    
    // 解放
    free(texData);
	[uimg release];
    
	return true;
}

/**
 * 保存領域へのパスを取得します.
 * @return パス
 */
const char* GCGetStoragePath(const char *fileName) {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	if (fileName) {
		return [[documentsDirectory stringByAppendingPathComponent:[NSString stringWithCString:fileName encoding:NSUTF8StringEncoding]] UTF8String];
	} else {
		return [documentsDirectory UTF8String];
	}
}


#pragma mark - GCViewController

#import "GCViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "EAGLView.h"

@interface GCViewController ()
@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, assign) CADisplayLink *displayLink;
@end


@implementation GCViewController

@synthesize animating;
@synthesize context;
@synthesize displayLink;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    NSLog(@"GCViewController:viewDidLoad");
    
	self.view.contentScaleFactor = [UIScreen mainScreen].scale;
	
    self.context = [[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2] autorelease];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    } else if (![EAGLContext setCurrentContext:self.context]) {
        NSLog(@"Failed to set ES context current");
    }
    
    EAGLView *view = (EAGLView *)self.view;
    view.context = self.context;
    [view setFramebuffer];
    
    animating = FALSE;
    animationFrameInterval = 2;
    self.displayLink = nil;
    
	if (!controller) {
		controller = ApplicationController::getInstance();
		CGRect screenSize = [[UIScreen mainScreen] bounds];
		float scale = [UIScreen mainScreen].scale;
        controller->resize(screenSize.size.width * scale, screenSize.size.height * scale);
		controller->resetup();
		controller->main->initApplicationController();
	} else {
		controller->resetup();
	}
    
    lastTime = CFAbsoluteTimeGetCurrent();
}

- (void)viewDidUnload
{
    NSLog(@"GCViewController:viewDidUnload");
    
	[debugButton release];
	debugButton = nil;
	[super viewDidUnload];
	
    // Tear down context.
    if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];
	self.context = nil;	
}

- (void)viewWillAppear:(BOOL)animated
{
    [self startAnimation];
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopAnimation];
    
    [super viewWillDisappear:animated];
}


#pragma mark - Events

// タッチイベント
- (void)toucheEvent:(NSSet *)touches withEvent:(UIEvent *)event withType:(int)type {
	float scale = [UIScreen mainScreen].scale;
	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self.view];
	if (controller) {
		controller->onTouch(type, location.x*scale, location.y*scale, touch.timestamp);
	}
}

// タッチ開始イベント
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[self toucheEvent:touches withEvent:event withType:0];
}

// タッチ移動イベント
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	[self toucheEvent:touches withEvent:event withType:2];
}

// タッチ終了イベント
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[self toucheEvent:touches withEvent:event withType:1];
}

// タッチキャンセルイベント
//- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
//}

// デバッグボタンイベント
- (IBAction)pressDebugButton:(id)sender {
	[self stopAnimation];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"debug" ofType:@"txt"];
	NSString *msg = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [alert show];
	[alert release];
}

// デバッグアラートイベント
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	[self startAnimation];
	if (buttonIndex==1 && controller) {
		UITextField *txt = [alertView textFieldAtIndex:0];
		NSArray *cmds = [[txt text] componentsSeparatedByString:@" "];
		if ([cmds count]>0) {
			NSString *str = [cmds objectAtIndex:0];
			int p = 0;
			if ([cmds count]>1) {
				p = [[cmds objectAtIndex:1] intValue];
			}
			const char* c = [str cStringUsingEncoding:NSUTF8StringEncoding];
			controller->onDebugCommand(c, p);
		}
	}
}

#pragma mark - DisplayLink

- (void)drawFrame
{
    CFTimeInterval interval = CFAbsoluteTimeGetCurrent() - lastTime;
    lastTime = CFAbsoluteTimeGetCurrent();
    [(EAGLView *)self.view setFramebuffer];
    
	if (controller) {
		controller->step(interval);
	} else {
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    
    [(EAGLView *)self.view presentFramebuffer];
}


#pragma mark - Properties

- (NSInteger)animationFrameInterval
{
    return animationFrameInterval;
}

- (void)setAnimationFrameInterval:(NSInteger)frameInterval
{
    /*
	 Frame interval defines how many display frames must pass between each time the display link fires.
	 The display link will only fire 30 times a second when the frame internal is two on a display that refreshes 60 times a second. The default frame interval setting of one will fire 60 times a second when the display refreshes at 60 times a second. A frame interval setting of less than one results in undefined behavior.
	 */
    if (frameInterval >= 1) {
        animationFrameInterval = frameInterval;
        
        if (animating) {
            [self stopAnimation];
            [self startAnimation];
        }
    }
}


#pragma mark - Public method

- (void)startAnimation
{
    NSLog(@"startAnimation");
    if (!animating) {
		lastTime = CFAbsoluteTimeGetCurrent();
        CADisplayLink *aDisplayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(drawFrame)];
        [aDisplayLink setFrameInterval:animationFrameInterval];
        [aDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.displayLink = aDisplayLink;
        
        animating = TRUE;
    }
}

- (void)stopAnimation
{
    if (animating) {
        [self.displayLink invalidate];
        self.displayLink = nil;
        animating = FALSE;
    }
}

- (void)suspend
{
	if (controller) {
		controller->onPause();
	}
}

- (void)resume
{
	if (controller) {
		controller->onResume();
	}
}


- (void)dealloc {
	[debugButton release];
	[super dealloc];
}
@end
