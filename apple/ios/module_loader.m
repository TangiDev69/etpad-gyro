// Only app-bundled, code-signed frameworks may supply executable game code.
// GPL-3.0-or-later; see COPYING.txt.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include "../../src/qcommon/q_shared.h"
#include "../../src/qcommon/qcommon.h"
void *ETPad_LoadBundledModule(const char *name, qboolean gameModule)
{
    const char *framework = NULL;
    if (gameModule) {
        if (Q_stricmp(Cvar_VariableString("fs_game"), "legacy"))
            Com_Error(ERR_DROP, "This server needs a mod ETPad can't run. Only the built-in Legacy mod is supported.");
        if (!strcmp(name,"cgame")) framework="ETPadCGame";
        else if (!strcmp(name,"ui")) framework="ETPadUI";
        else if (!strcmp(name,"qagame")) framework="ETPadGame";
    } else if (!strcmp(name,"librenderer_opengles_mac")) framework="ETPadRenderer";
    if (!framework) {
        Com_Printf("ETPad refused native module: %s\n",name);
        return NULL;
    }
    NSString *base = NSBundle.mainBundle.privateFrameworksPath;
    NSString *path = [base stringByAppendingPathComponent:[NSString stringWithFormat:@"%s.framework/%s",framework,framework]];
    void *handle=dlopen(path.fileSystemRepresentation, RTLD_NOW|RTLD_LOCAL);
    if (!handle) Com_Printf("ETPad bundled framework %s failed: %s\n",framework,dlerror());
    return handle;
}
