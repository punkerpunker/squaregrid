import sys
sys.path.append('/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/')
from processing.geocoder import parse_geo_json
import pandas as pd
from sqlalchemy import create_engine
from processing.geocoder_pb2 import GeocodeCSVRequest, GeocodeCSVResponse
from processing.geocoder_pb2 import StoredRequest, PullProcessedDataResponse
from processing.geocoder_pb2 import PullProcessedDataRequest
from processing import geocoder_pb2_grpc
from processing.geocoder_pb2_grpc import GeocoderServicer, GeocoderStub
from utils.flask import FlaskServingThread
import argparse
from collections import defaultdict
from concurrent import futures
from flask import Flask, request, render_template
from hashlib import sha256
import io
import itertools
import json
import logging
import os
import pandas
import requests
import signal
import sqlalchemy
import time
from threading import Thread, Lock

import grpc


def main():
    df = pd.read_sql_query('select  * from data_marts.bin_geocoding_20171123', engine)
    df = parse_geo_json(df, whitelist = ['country_code','country','county','state','city','street',
                                         'housenumber','address','latlong','bbox','accuracy','quality'])
    df.to_csv('bin_addresses.csv',index=False)

if __name__ == '__main__':
    main()