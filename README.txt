Step-by-step
1) Generate Qsys files.
1.1) Open cycloneV_soc.qsys and GENERATE

2)Run Analysis and Sinthesys in Quartus.

3) TCL script -> sdram pin assignment

4) Full compile in Quartus

5) Create header files:
5.1) use nios2 command shell para carregar sopc-create-header-files 
5.2) sopc-create-header-files cycloneV_soc.sopcinfo --output-dir qsys_headers/

6) Make na aplicacao linux_app

7) Passe o binario para a placa, via sd-card ou outra coisa

8) entre na placa com m linux carregado e execute 
