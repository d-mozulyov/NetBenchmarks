@echo off

set Protocol=TCP
set Benchmark=bin\%Protocol%\benchmark.%Protocol%

echo %Protocol% Server running...
%Benchmark% "Indy.%Protocol%"
%Benchmark% "IndyPool.%Protocol%"
%Benchmark% "RealThinClient.%Protocol%"
%Benchmark% "Synopse.%Protocol%"
%Benchmark% "TMSSparkle.%Protocol%"
%Benchmark% "node ../../source/Node.js/Node.%Protocol%.js"
%Benchmark% "Golang.%Protocol%"

pause