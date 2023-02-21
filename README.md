# massSpecker: find targets/suspects in peaklist

### Create Environment

First, we create and activate an environment in conda. Run the following commands:

```bash
$ conda create --name massSpecker --file requirements.txt
$ conda activate massSpecker
```

Install development version of _datasette_:

```bash
$ pip install datasette==1.0a2
```

### Run Script

Navigate into the _massSpecker_ folder and invoke the script as follows:

```bash
$ Rscript code/find_targets.R --peaklist data/peaklist.csv --database data/database.db --output output/results.db
```

Or simply:

```bash
$ Rscript code/find_targets.R -p data/peaklist.csv
```

### Visualize Results using Datasette

Either publish the results directly using Datasette:

```bash
$ datasette -p 8080 output/results.db
```

Or start a docker image and publish the results in the isolated docker image. First start Docker Desktop, and then run the command below (which will automatically download the corresponding docker image):

```bash
$ docker run -p 8080:8080 -v `pwd`:/mnt \
    datasetteproject/datasette \
    datasette -p 8080 -h 0.0.0.0 /mnt/output/results.db
```

Open Browser and type http://127.0.0.1:8080/ or localhost:8080

### Directly access the compound list from Datasette

First, we publish the compound database to Datasette:

```bash
$ datasette -p 8080 data/database.db 
```

Then, we can directly access the data from _datasette_ by setting the compound argument to the corresponding API call in the second version of the script (_find_targets_v2.R_):

```bash
$ Rscript code/find_targets_v2.R --peaklist data/peaklist.csv --compoundlist 'http://localhost:8080/database/compoundlist.csv?_size=max'
```



