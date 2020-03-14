import squaregrid.radii as r

def get_build_location():
    return r.__file__.rstrip('__init__.py')+'build'
