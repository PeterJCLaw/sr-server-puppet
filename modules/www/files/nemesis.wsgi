import sys
sys.path.insert(0, "/srv/nemesis/nemesis")

from app import app as application

application.config['PREFERRED_URL_SCHEME'] = 'https'
