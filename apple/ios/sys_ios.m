// ETPad iOS platform glue. GPL-3.0-or-later; see COPYING.txt.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#include "../../src/qcommon/q_shared.h"
#include "../../src/qcommon/qcommon.h"
#include "../../src/sys/sys_local.h"

dialogResult_t Sys_Dialog(dialogType_t type, const char *message, const char *title)
{
    NSLog(@"ETPad: %s: %s", title, message);
    // The native host owns presentation. Never synchronously block UIKit here.
    return type == DT_YES_NO ? DR_NO : type == DT_OK_CANCEL ? DR_CANCEL : DR_OK;
}
const char *OSX_ApplicationSupportPath(void)
{
    static char path[1024];
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).lastObject;
    Q_strncpyz(path, directory.UTF8String, sizeof(path));
    return path;
}
int OSX_NeedsQuarantineFix(void) { return 0; }

void ETPad_MetalDrawable(void *pointer,int width,int height)
{
    CAMetalLayer *layer=(CAMetalLayer *)pointer;
    // SDL initially sizes its Metal UIView in the requested render dimensions.
    // Keep presentation in UIKit points independent of the drawable pixels.
    UIView *metalView=[layer.delegate isKindOfClass:UIView.class] ? (UIView *)layer.delegate : nil;
    if(metalView.superview && !CGRectEqualToRect(metalView.frame,metalView.superview.bounds)){
        metalView.frame=metalView.superview.bounds;
        metalView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    }
    // ANGLE Metal derives its framebuffer from bounds * contentsScale and
    // overwrites drawableSize. Match that calculation to the render width.
    CGFloat presentationWidth=layer.bounds.size.width;
    if(presentationWidth>0){
        CGFloat scale=(CGFloat)width/presentationWidth;
        if(layer.contentsScale!=scale)layer.contentsScale=scale;
    }
    CGSize size=CGSizeMake(width,height);
    if(!CGSizeEqualToSize(layer.drawableSize,size))layer.drawableSize=size;
}

void ETPad_AttachRenderWindow(void *pointer)
{
    UIWindow *window=(UIWindow *)pointer;
    // Attach to the scene that owns the native host window. An external
    // display's scene can also be foreground-active and must never own SDL's
    // window, or the game would take that screen's size and orientation.
    UIWindowScene *owner=nil;
    for(UIScene *candidate in UIApplication.sharedApplication.connectedScenes){
        if(![candidate isKindOfClass:UIWindowScene.class] || ![candidate.session.role isEqualToString:UIWindowSceneSessionRoleApplication])continue;
        UIWindowScene *scene=(UIWindowScene *)candidate;
        if(!owner || scene.activationState==UISceneActivationStateForegroundActive)owner=scene;
    }
    if(owner){
        UIWindowScene *scene=owner;
        window.windowScene=scene;
        window.frame=scene.coordinateSpace.bounds;
        window.userInteractionEnabled=NO;
        [window.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
        [window layoutIfNeeded];
        NSLog(@"ETPad renderer attached before Metal: frame=%@ bounds=%@ root=%@ orientation=%ld",NSStringFromCGRect(window.frame),NSStringFromCGRect(window.bounds),NSStringFromCGRect(window.rootViewController.view.frame),(long)scene.interfaceOrientation);
    }
}
