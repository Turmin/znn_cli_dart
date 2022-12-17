default: all

all:
	echo Use 'make windows' or 'make linux' to build the znn-cli binary

windows:
	-mkdir build
	dart compile exe cli_handler.dart -o build\znn-cli.exe
	copy .\Resources\* .\build\
	
linux: 
	mkdir -p build
	dart compile exe cli_handler.dart -o build/znn-cli
	cp ./Resources/* ./build
	
