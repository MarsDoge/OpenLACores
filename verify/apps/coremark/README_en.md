#	CoreMark

CoreMark's primary goals are simplicity and providing a method for testing only a processor's core features. For more information about EEMBC's comprehensive embedded benchmark suites, please see www.eembc.org.

For a more compute-intensive version of CoreMark that uses larger datasets and execution loops taken from common applications, please check out EEMBC's [CoreMark-PRO](https://www.github.com/eembc/coremark-pro) benchmark, also on GitHub.

## Building and Running with Cross Compiling

run:
~~~
make CROSS_COMPILE=</path/to/cross_compile> -j<thread>
~~~

# Log File Format
The log files have the following format

~~~
2K performance run parameters for coremark.	(Run type)
CoreMark Size    	: 666					(Buffer size)
Total ticks			: 25875					(platform dependent value)
Total time (secs) 	: 25.875000				(actual time in seconds)
Iterations/Sec 		: 3864.734300			(Performance value to report)
Iterations			: 100000				(number of iterations used)
Compiler version	: GCC3.4.4				(Compiler and version)	
Compiler flags		: -O2					(Compiler and linker flags)
Memory location		: Code in flash, data in on chip RAM
seedcrc				: 0xe9f5				(identifier for the input seeds)
[0]crclist			: 0xe714				(validation for list part)
[0]crcmatrix		: 0x1fd7				(validation for matrix part)
[0]crcstate			: 0x8e3a				(validation for state part)
[0]crcfinal			: 0x33ff				(iteration dependent output)
Correct operation validated. See README.md for run and reporting rules.  (*Only when run is successful*)
CoreMark 1.0 : 6508.490622 / GCC3.4.4 -O2 / Heap 						  (*Only on a successful performance run*)
~~~

# Copyright
Copyright © 2009 EEMBC All rights reserved. 
CoreMark is a trademark of EEMBC and EEMBC is a registered trademark of the Embedded Microprocessor Benchmark Consortium.
