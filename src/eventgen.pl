#!/usr/local/bin/perl -w
# impl.pl.eventgen -- Generator for impl.h.eventgen
#
# Copyright (C) 1997 Harlequin Group, all rights reserved.
# $HopeName: !eventgen.pl(MMdevel_metrics.1) $
#
# Invoke this script in the src directory.
# It works by scanning *.c for EVENT_[A-Z], 
# and then creating a file eventgen.h that includes the
# necessary types and macros.  If the format letter doesn't
# exist as a WriteF format type, then the subsequent compile
# will fail.
#
# You will need to have eventgen.h claimed, and you should
# remember to check it in afterwards.
#
# @@@@ This tool is supported on UNIX only. 

%Formats = ();

%Types = (
  "D", "double",
  "S", "char *",
  "U", "unsigned",
  "W", "Word",
  "A", "struct AddrStruct *",
  "P", "void *",
	  );

while(<*.c>) {
  open(C, "<$_") || die "Can't open $_";

  print STDERR "$_ ... ";

  while(<C>) {
    if(/EVENT_([A-Z]+)\(/) { 
      $Formats{$1} = 1 if(!defined($Formats{$1}));
    }
  }

  close(C);
}

print STDERR "\n";

open(H, ">eventgen.h") || die "Can't open eventgen.h for output";

print H "/* impl.h.eventgen -- Automatic event header
 *
 * Copyright (C) 1997 Harlequin Group, all rights reserved.
 * \$HopeName\$
 *
 * !!! DO NOT EDIT THIS FILE !!!
 * This file was generated by eventgen.pl
 */\n\n";

print H "#ifdef EVENT\n\n";

foreach $format ("", sort(keys(%Formats))) {
  print H "typedef struct {\n";
  print H "  Word code;\n  Word length;\n  Word clock;\n";
  for($i = 0; $i < length($format); $i++) {
    $c = substr($format, $i, 1);
    if($c eq "S") {
      die "String must be at end of format" if($1+1 != length($format));
      print H "  char s[EventMaxStringLength];\n";
    } elsif(!defined($Types{$c})) {
      die "Can't find type for format code >$c<.";
    } else {
      print H "  ", $Types{$c}, " \l$c$i;\n";
    }
  }
  print H "} Event", $format, "Struct;\n\n";
}

print H "\ntypedef union {\n  EventStruct any;\n";

foreach $format (sort(keys(%Formats))) {
  print H "  Event${format}Struct \L$format;\n";
}
print H "} EventUnion;\n\n\n";


print H "#define EVENT_0(type) \\
  EVENT_BEGIN(type, 0, sizeof(EventStruct)) \\
  EVENT_END(type, sizeof(EventStruct))\n\n";

foreach $format (sort(keys(%Formats))) {
  print H "#define EVENT_$format(type";

  for($i = 0; $i < length($format); $i++) {
    $c = substr($format, $i, 1);
    if($c eq "S") {
      print H ", _s";
    } else {
      print H ", _\l$c$i";
    }
  }

  print H ") \\\n";

  print H "  BEGIN \\\n";

  if(index($format, "S") != -1) {
    print H "    char *_s2 = (_s); \\\n"; # May be literal
    print H "    size_t _string_length = StringLength((_s2)); \\\n";
    print H "    size_t _length = \\\n";
    print H "      WordAlignUp(offsetof(Event${format}Struct, s) + \\\n";
    print H "                  _string_length + 1, sizeof(Word)); \\\n";
  } else {
    print H "    size_t _length = sizeof(Event${format}Struct); \\\n";
  }

  print H "    EVENT_BEGIN(type, $format, _length); \\\n";

  for($i = 0; $i < length($format); $i++) {
    $c = substr($format, $i, 1);
    if($c eq "S") {
      print H 
        "    _memcpy(Event.\L$format.s, (_s2), _string_length + 1); \\\n";
    } else {
      print H "    Event.\L$format.$c$i = (_$c$i); \\\n";
    }
  }

    print H "    EVENT_END(type, _length); \\\n";
    print H "  END\n\n";
}

$C = 0;
foreach $format ("0", sort(keys(%Formats))) {
  print H "#define EventFormat$format $C\n";
  $C++;
}

print H "\n#else /* EVENT not */\n\n";

print H "#define EVENT_0(type)    NOOP\n";

foreach $format (sort(keys(%Formats))) {
  print H "#define EVENT_$format(type";
  for($i = 0; $i < length($format); $i++) {
    print H ", p$i";
  }
  print H ")    NOOP\n";
}

print H "\n#endif /* EVENT */\n";

close(H);
