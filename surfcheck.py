# Copyright (c) 2014 Eric Allen Youngson

"""This module is intended to mimick the functionality of the perl script:
    surfcheck.pl by kurtwindisch@yahoo.com"""
# Written by Eric Youngson eric@scneco.com / eayoungs@gmail.com
# Succession Ecological Services: Portland, Oregon


import requests


# **********************************************************************
# From: NOAA Web svs http://www.ncdc.noaa.gov/cdo-web/webservices/v2
# **********************************************************************

# Primary API  for noaa Climate Data Online [CDO]
# http://www.ncdc.noaa.gov/cdo-web/api/v2/{endpoint}
#
# Sample usage (requires token):
# curl -H "token:<token>" url
# $.ajax({ url:<url>, data:{<data>}, headers:{ token:<token> } })

# **********************************************************************
# From: oregonsurfcheck.com Perl script (surfcheck.pl)
# **********************************************************************

# NWS_Coastal_Primary_URL
"http://www.wrh.noaa.gov/pqr"
"http://www.wrh.noaa.gov/total_forecast/marine.php?marine=PZZ255"

# NWS_Coastal_Data_URL
"http://www.wrh.noaa.gov/total_forecast/marine.php?marine=PZZ255"


