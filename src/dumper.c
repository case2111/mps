/* impl.c.dumper: Simple Event Dumper
 *
 * $HopeName: !dumper.c(MMdevel_metrics.1) $
 * Copyright (C) 1997 Harlequin Group, all rights reserved.
 *
 * .readership: MM developers.
 *
 * .purpose: This is a simple tool to dump events as text.
 *
 * .trans: As a tool, it's allowed to depend on the ANSI C library.
 */

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdarg.h>
#include <assert.h>
#include "ossu.h"

typedef unsigned long Word;
typedef struct AddrStruct *Addr;

#include "eventcom.h"


#define RELATION(type, code, always, kind, format) \
  case Event ## type: \
    readEvent(#type, #format, header[0], header[1], header[2]); \
    break; 


#define AVER(test) \
  if(test) do {} while(0); else error("AVER: " #test)


static char *prog;


static void error (const char *format, ...) {
  va_list args;
  fprintf(stderr, "%s: Error: ", prog);
  va_start(args, format);
  vfprintf(stderr, format, args);
  fputc('\n', stderr);
  va_end(args);
  exit(EXIT_FAILURE);
  assert(0);
}


#define PROCESS(ch, type, _length, printfFormat, cast) \
  case ch: { \
    type v; \
    size_t n = fread(&v, (_length), 1, stdin); \
    if(n < 1) \
      error("Can't read data for format code >%c<", ch); \
    printf(printfFormat " ", (cast)v); \
    length -= (_length) / sizeof(Word); \
  } break;


static void readEvent(char *type, char *format, Word code, Word length,
		      Word cpuTime) {
  AVER(type != NULL);
  AVER(format != NULL);

  printf("%-20s ", type);

  for(; *format != '\0'; format++) {
    switch(*format) {
      PROCESS('A', Addr, sizeof(Addr), "0x%08lX", unsigned long)
      PROCESS('P', void *, sizeof(void *), "0x%08lX", unsigned long)
      PROCESS('U', unsigned, sizeof(unsigned),"%u", unsigned)
      PROCESS('W', Word, sizeof(Word),"%lu", Word)
      PROCESS('D', double, sizeof(double), "%f", double)
      case 'S': {
        size_t n;
        char *v;
        AVER(length > 0);
        v = malloc(length * sizeof(Word));
        if(v == NULL)
          error("Can't allocate string space %u", (unsigned)length);
        n = fread(&v, length * sizeof(Word), 1, stdin); 
        if(n < 1) 
          error("Can't read data for string"); 
        printf("%s  ", v); 
        length = 0;
      } break;
      case '0': break;
      default:
        error("Unknown format >%c<", *format);
        break;
    }
  }
  putc('\n', stdout);

  AVER(length == 0);
}

        
int main(int argc, char *argv[]) {
  size_t n;
  Word header[3];

  prog = (argc >= 1 ? argv[0] : "unknown");

  while(!feof(stdin)) {
    n = fread(header, sizeof(Word), 3, stdin);
    if(n < 3) {
      if(feof(stdin))
        continue;
      error("Can't read from input");
    }
    
    switch(header[0]) {
#include "eventdef.h"
      default:
      error("Unknown event code %08lX", header[0]);
    }
  }
  return(0);
}
  
      
