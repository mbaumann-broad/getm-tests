# getm-tests
Tests for getm

## local testing
To test the workflow on your local machine using [MiniWDL](https://github.com/chanzuckerberg/miniwdl.git):

Install requirements
```
pip install -r requirements.txt
sudo apt-get install shellcheck
gcloud auth application-default login
```

Authenticate
```
gcloud auth application-default login
```

Run local tests
```
make test
```
