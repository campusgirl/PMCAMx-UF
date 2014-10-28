#!/bin/csh

#This short script processes gmon.out profiling information for
#  PMCAMx.exe and makes a png image of the profile.
#  In order to generate the gmon.out file, you need to compile
#  the PMCAMx.exe executable with the flag -pg, and you should
#  likely turn off most optimization routines.

#First run gprof to process the profile binary into something 
#readable. Then use gprof2dat.py to transfer it to a dot image.
#Then convert to png
#

    gprof ../PMCAMx.exe ./gmon.out | gprof2dot.py | dot -Tpng -o PMCAMx_prof.png
   
