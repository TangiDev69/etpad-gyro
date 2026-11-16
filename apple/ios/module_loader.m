// Only app-bundled, code-signed frameworks may supply executable game code.
// GPL-3.0-or-later; see COPYING.txt.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include "../../src/client/keys.h"
#include "../../src/qcommon/q_shared.h"
#include "../../src/qcommon/qcommon.h"
static void (*uiPointer)(float,float),(*gamePointer)(float,float);
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
    if(handle && gameModule){
        // Preserve ET's cross-platform pure-pak accounting using archive
        // metadata only. No executable image is extracted or loaded; the
        // signed framework above supplies code.
        fileHandle_t reference=0;
        char entry[MAX_QPATH];
        Com_sprintf(entry,sizeof(entry),"%s_mac",name);
        if(FS_FileIsInPAK(entry,NULL)==1){
            FS_FOpenFileRead_Filtered(entry,&reference,qfalse,FS_EXCLUDE_DIR);
            if(reference)FS_FCloseFile(reference);
        }
        if(!strcmp(name,"ui"))uiPointer=dlsym(handle,"etpad_module_pointer");
        if(!strcmp(name,"cgame"))gamePointer=dlsym(handle,"etpad_module_pointer");
    }
    return handle;
}

void ETPad_SetModulePointer(float x,float y)
{
    // Engine key catchers use UI bit 2 and cgame bit 8 (qcommon.h).
    int catcher=Key_GetCatcher();
    if((catcher & KEYCATCH_UI) && uiPointer)uiPointer(x,y);
    else if((catcher & KEYCATCH_CGAME) && gamePointer)gamePointer(x,y);
}
