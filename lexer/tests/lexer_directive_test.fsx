#!/usr/bin/env -S dotnet fsi
#if DEBUG
let configuration = "debug"
#else
let configuration = "release"
#endif

#line 100 "generated.fs"
# 120
#nowarn "40"
#light "off"
#r "library.dll"
#load "shared.fsx"
#I "packages"
#time "on"
#help
#quit
