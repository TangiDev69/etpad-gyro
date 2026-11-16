// Data-only extraction of the pinned official installer. Never execute its code.
// GPL-3.0-or-later. Hash verification belongs to the native acquisition layer.
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <zlib.h>
#include <unzip.h>
static int read_exact(gzFile input,void *buffer,size_t size)
{
    unsigned char *p=buffer;
    while(size){int count=gzread(input,p,(unsigned)(size>65536?65536:size));if(count<=0)return -1;p+=count;size-=count;}
    return 0;
}
__attribute__((visibility("default"))) int etpad_extract_official(const char *archive,const char *directory)
{
    char path[4096],header[16385];unsigned char buffer[65536],tar[512];
    FILE *run=NULL,*output=NULL;gzFile payload=NULL;unzFile zip=NULL;int result=-1,found=0,entryOpen=0;
    if(snprintf(path,sizeof path,"%s/installer.run",directory)>=(int)sizeof path)return -1;
    zip=unzOpen(archive);if(!zip)goto done;
    if(unzLocateFile(zip,"et260b.x86_keygen_V03.run",1)!=UNZ_OK || unzOpenCurrentFile(zip)!=UNZ_OK)goto done;
    entryOpen=1;run=fopen(path,"w+b");if(!run)goto done;
    int count;
    while((count=unzReadCurrentFile(zip,buffer,sizeof buffer))>0)if(fwrite(buffer,1,count,run)!=(size_t)count)goto done;
    if(count<0 || unzCloseCurrentFile(zip)!=UNZ_OK)goto done;
    entryOpen=0;unzClose(zip);zip=NULL;
    rewind(run);size_t bytes=fread(header,1,sizeof(header)-1,run);header[bytes]=0;
    char *field=strstr(header,"\nfilesizes=\"");if(!field)goto done;
    char *end;long long size=strtoll(field+12,&end,10);
    if(size<=0 || size>1024LL*1024*1024 || *end!='"')goto done;
    if(fseeko(run,0,SEEK_END))goto done;
    off_t total=ftello(run);if(total<size)goto done;
    // Use a fresh descriptor: stdio buffering must not move the gzip offset.
    FILE *input=fopen(path,"rb");if(!input)goto done;
    int fd=dup(fileno(input));fclose(input);
    if(fd<0)goto done;
    if(lseek(fd,total-size,SEEK_SET)<0){close(fd);goto done;}
    payload=gzdopen(fd,"rb");if(!payload){close(fd);goto done;}
    for(;;){
        if(read_exact(payload,tar,512))goto done;
        if(!tar[0])break;
        unsigned stored=0,sum=0;
        for(int i=148;i<156;i++){if(tar[i]>='0'&&tar[i]<='7')stored=stored*8+tar[i]-'0';}
        for(int i=0;i<512;i++)sum+=(i>=148&&i<156)?' ':tar[i];
        if(stored!=sum)goto done;
        uint64_t length=0;
        for(int i=124;i<136;i++){
            if(tar[i]>='0'&&tar[i]<='7')length=length*8+tar[i]-'0';
            else if(tar[i]!=0 && tar[i]!=' ')goto done;
            if(length>1024ULL*1024*1024)goto done;
        }
        char name[101];memcpy(name,tar,100);name[100]=0;
        const char *relative=name;if(!strncmp(relative,"./",2))relative+=2;
        int index=-1;
        for(int i=0;i<3;i++){char expected[20];snprintf(expected,sizeof expected,"etmain/pak%d.pk3",i);if(!strcmp(relative,expected))index=i;}
        if(index>=0){
            if((tar[156]!=0 && tar[156]!='0') || (found&(1<<index)))goto done;
            if(snprintf(path,sizeof path,"%s/pak%d.pk3",directory,index)>=(int)sizeof path)goto done;
            output=fopen(path,"wb");if(!output)goto done;
            found|=1<<index;
        }
        uint64_t remaining=length;
        while(remaining){size_t chunk=remaining>sizeof buffer?sizeof buffer:(size_t)remaining;
            if(read_exact(payload,buffer,chunk))goto done;
            if(output && fwrite(buffer,1,chunk,output)!=chunk)goto done;
            remaining-=chunk;
        }
        if(output){if(fclose(output)){output=NULL;goto done;}output=NULL;}
        unsigned padding=(512-(length%512))%512;
        if(padding && read_exact(payload,buffer,padding))goto done;
    }
    result=found==7?0:-1;
done:
    if(output)fclose(output);
    if(payload && gzclose(payload)!=Z_OK)result=-1;
    if(run)fclose(run);
    if(zip){if(entryOpen)unzCloseCurrentFile(zip);unzClose(zip);}
    return result;
}
