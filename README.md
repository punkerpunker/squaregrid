# Squaregrid

Squaregrid - framework to work with square grids contains multiple squares

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

First, you need to install cmake and boost:

```
sudo apt-get install cmake
sudo apt-get install libboost-all-dev
```

Then, you need to compile protobuf:

```
sudo apt-get install autoconf automake libtool curl make g++ unzip -y
git clone https://github.com/google/protobuf.git
cd protobuf
git submodule update --init --recursive
./configure
./autogen.sh
make
make check
sudo make install
sudo ldconfig
```

### Installing

Installation could be as simple as:

```
sudo pip3 install squaregrid
```

To verify installation try: 

```python
import squaregrid
```

## Built With

* [cmake](https://cmake.org/documentation/) - The C++ frameworks used

## Contributing

Please read [CONTRIBUTING](https://marketing-logic.atlassian.net/wiki/spaces/ML/pages/96600066/DevOps) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors

* **Dmitry Ivashcenko** - *Initial work* - [FatMan](https://github.com/fatman)
* **Gleb Vazhenin** - *Python implementation* - [punkerpunker](https://github.com/punkerpunker)


## License

This project doesn't have any license yet.

