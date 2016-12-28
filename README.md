```
checkversion --remote 'http://clipserve.clip.ubc.ca/topfind/download' --regex 'downloads/([\d_A-Za-z]+)\.sql' --print || echo 'This will always give a non-zero exit code'
```
