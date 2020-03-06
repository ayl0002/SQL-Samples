import numpy as np
import datetime as dt

import sqlalchemy
from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, func

from flask import Flask, jsonify

engine = create_engine("sqlite:///hawaii.sqlite")
Base = automap_base()
Base.prepare(engine, reflect=True)

Measurement = Base.classes.measurement
Station = Base.classes.station

app = Flask(__name__)

@app.route("/")
def welcome():
    return (
        f"<br/>"
        f"/api/v1.0/precipitation<br/>"
        f"/api/v1.0/stations<br/>"
        f"/api/v1.0/tobs<br/>"
        f"/api/v1.0/yyyy-mm-dd<br/>"
        f"/api/v1.0/yyyy-mm-dd/yyyy-mm-dd"
    )

@app.route('/api/v1.0/<start>')
def get_t_start(start):
    session = Session(engine)
    queryresult = session.query(func.min(Measurement.tobs), func.avg(Measurement.tobs), func.max(Measurement.tobs)).\
        filter(Measurement.date >= start).all()
    session.close()

    list1 = []
    for min,avg,max in queryresult:
        first_dict = {}
        first_dict["Min"] = min
        first_dict["Average"] = avg
        first_dict["Max"] = max
        list1.append(first_dict)

    return jsonify(list1)

@app.route('/api/v1.0/<start>/<stop>')
def get_t_start_stop(start,stop):
    session = Session(engine)
    queryresult = session.query(func.min(Measurement.tobs), func.avg(Measurement.tobs), func.max(Measurement.tobs)).\
        filter(Measurement.date >= start).filter(Measurement.date <= stop).all()
    session.close()

    list1 = []
    for min,avg,max in queryresult:
        first_dict = {}
        first_dict["Min"] = min
        first_dict["Average"] = avg
        first_dict["Max"] = max
        list1.append(first_dict)

    return jsonify(list1)

@app.route('/api/v1.0/tobs')
def tobs():
    session = Session(engine)
    lateststr = session.query(Measurement.date).order_by(Measurement.date.desc()).first()[0]
    latestdate = dt.datetime.strptime(lateststr, '%Y-%m-%d')
    querydate = dt.date(latestdate.year -1, latestdate.month, latestdate.day)
    sel = [Measurement.date,Measurement.tobs]
    queryresult = session.query(*sel).filter(Measurement.date >= querydate).all()
    session.close()

    list1 = []
    for date, tobs in queryresult:
        first_dict = {}
        first_dict["Date"] = date
        first_dict["Tobs"] = tobs
        list1.append(first_dict)

    return jsonify(list1)

@app.route('/api/v1.0/stations')
def stations():
    session = Session(engine)
    sel = [Station.station,Station.name,Station.latitude,Station.longitude,Station.elevation]
    queryresult = session.query(*sel).all()
    session.close()

    stations = []
    for station,name,lat,lon,el in queryresult:
        Stations = {}
        Stations["Station"] = station
        Stations["Name"] = name
        Stations["Lat"] = lat
        Stations["Lon"] = lon
        Stations["Elevation"] = el
        stations.append(Stations)

    return jsonify(stations)

@app.route('/api/v1.0/precipitation')
def precipitation():
    session = Session(engine)
    sel = [Measurement.date,Measurement.prcp]
    queryresult = session.query(*sel).all()
    session.close()

    precipitation = []
    for date, prcp in queryresult:
        dict_3 = {}
        dict_3["Date"] = date
        dict_3["Precipitation"] = prcp
        precipitation.append(dict_3)

    return jsonify(precipitation)

if __name__ == '__main__':
    app.run(debug=True)