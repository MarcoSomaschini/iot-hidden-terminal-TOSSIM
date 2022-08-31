<p align="center">
  <img width="300" src="docs/Latex/images/logo.png" alt="PoliMi Logo" />
  <br>
  <i><font size="3">
  	Internet of Things - Optional Project - AA 2021/2022 - Prof. Matteo Cesana
    </font>
  </i>
</p>
<h1 align="center">
	<strong>
	The Hidden Terminal
	</strong>
	<br>
</h1>
<p align="center">
<font size="3">	
		<a href="http://www.tinyos.net/">TinyOS</a>		 
		•
		<a href="docs/report.pdf">Report</a>   
	</font>
</p>

A TinyOS project that simulates an Hidden Terminal scenario and its solution through the RTS/CTS protocol. 

## Versions
* The **master** branch hosts a version of the application that does not implement the RTS/CTS protocol.
* The **rts-cts** branch, instead, hosts a version that implements RTS/CTS.

## Compile & Run
To compile the project, open a terminal inside the root folder and input the following command:
```console
make micaz sim
```
After compiling, to run the simulation, write:
```console
python RunSimulationScript.py > simLog.log
```
The simulation log will be written in the file `simLog.log` and placed in the project root folder. 

## Author
*Somaschini Marco*
