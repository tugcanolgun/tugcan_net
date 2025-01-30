---
title: In memory zip creation
---
Sometimes it is necessary to combine files into a zip without actually storing them. One example could be to put a screenshot along with some legal text.

In order to achieve this in python

```python
from io import BytesIO
from zipfile import ZipFile


def create_archive(file_name: str, content: bytes) -> ZipFile:
    archive = BytesIO()
    with ZipFile(archive, 'w') as zip_file:
        with zip_file.open(file_name, 'w') as f:
            f.write(content)

        return zip_file
```

`archive` can be returned via flask with a specified name:

```python
from io import BytesIO
from zipfile import ZipFile
from flask import Flask, Response

app = Flask(__name__)


def _create_archive(file_name: str, content: bytes) -> BytesIO:
    archive = BytesIO()
    with ZipFile(archive, 'w') as zip_file:
        with zip_file.open(file_name, 'w') as f:
            f.write(content)

    return archive


@app.route("/")
def hello_world():
    archive: BytesIO = _create_archive("legal.txt", b"This is the legal text")

    response = Response(archive.getvalue(), mimetype="application/zip")
    response.headers.set("Content-Disposition", "attachment", filename="archive.zip")

    return response
```

If you want to download an extra file and include it in the zip file, you need to take care of getting the name of the file. Name of the file may contain url encoded characters such as `%20` for space. 

```python
from pathlib import Path
from urllib.parse import unquote, urlparse

url = "https://someurl/some%20picture.jpg?trackid=sometrackingid"

# Use urlparse so that the url parameters could be ignored
print(urlparse(url).path)
# > /some%20picture.jpg

# Use Path to get the name of the file without the directory dividers
print(Path(urlparse(url).path).name)
# > some%20picture.jpg

# Use unquote to get rid of the url encoding
print(unquote(Path(urlparse(url).path).name))
# > some picture.jpg
```

Here is the full code:

```python
from io import BytesIO
from pathlib import Path
from urllib.parse import unquote, urlparse
from zipfile import ZipFile
from flask import Flask, Response
import requests

app = Flask(__name__)


def _create_archive(file_name: str, content: bytes) -> BytesIO:
    archive = BytesIO()
    url = "https://someurl/some%20picture.jpg?trackid=sometrackingid"
    response = requests.get(url)
    file_name = unquote(Path(urlparse(url).path).name)
    with ZipFile(archive, "w") as zip_file:
        with zip_file.open(file_name, "w") as f:
            f.write(content)
        with zip_file.open(file_name, "w") as f:
            f.write(response.content)

    return archive


@app.route("/")
def hello_world():
    archive = _create_zip_archive()

    response = Response(archive.getvalue(), mimetype="application/zip")
    response.headers.set("Content-Disposition", "attachment", filename="archive.zip")

    return response
```