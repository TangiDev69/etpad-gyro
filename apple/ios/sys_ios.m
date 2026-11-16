// ETPad iOS platform glue. GPL-3.0-or-later; see COPYING.txt.
#import <Foundation/Foundation.h>
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
