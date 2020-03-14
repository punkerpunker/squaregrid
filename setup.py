import os
import shutil
import site
import pathlib
import subprocess
from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext as build_ext_orig

def main():
    setup(
        name='squaregrid',
        version='0.6.3',
        packages=find_packages(),
        ext_modules=[CMakeExtension('squaregrid')],
        cmdclass={
            'build_ext': build_ext,
        },
        install_requires=['pathlib', 'geopy', 'pgbase'],
    )

class CMakeExtension(Extension):

    def __init__(self, name):
        super().__init__(name, sources=[])


class build_ext(build_ext_orig):

    def run(self):
        try:
            out = subprocess.check_output(['cmake', '--version'])
        except OSError:
            raise RuntimeError(
                "CMake must be installed to build the following extensions: " +
                ", ".join(e.name for e in self.extensions))
        try:
            out = subprocess.check_output(['protoc', '--version'])
        except OSError:
            raise RuntimeError('Protobuf must be installed to build the following extensions: ' + ', '.join(e.name for e in self.extensions))
        try:
            out = subprocess.check_output(['dpkg -s libboost-dev | grep \'Version\''], shell=True)
        except OSError:
            raise RuntimeError('Boost must be installed to build the following extensions: ' + ', '.join(e.name for e in self.extensions))
        for ext in self.extensions:
            self.build_cmake(ext)
        super().run()

    def build_cmake(self, ext):
        cwd = pathlib.Path().absolute()
        
        radii_dir = str(pathlib.Path().absolute())+'/squaregrid/radii'
        # these dirs will be created in build_py, so if you don't have
        # any python sources to bundle, the dirs will be missing
        build_temp = pathlib.Path(site.getsitepackages()[0]+'/squaregrid/radii/build')
        try:
            shutil.rmtree(str(build_temp))
        except FileNotFoundError:
            pass
        build_temp.mkdir(parents=True, exist_ok=True)
        extdir = pathlib.Path(self.get_ext_fullpath(ext.name))
        extdir.mkdir(parents=True, exist_ok=True)

        # example of cmake args
        config = 'Debug' if self.debug else 'Release'
        cmake_args = []

        # example of build args
        build_args = ['--config', config, '--', '-j4', '-i']

        os.chdir(str(build_temp))
        self.spawn(['cmake', str(radii_dir)] + cmake_args)
        if not self.dry_run:
            self.spawn(['cmake', '--build', '.'] + build_args)
        os.chdir(str(cwd))

main()
