search-prototype
================

Search server prototype using data from LTI's official repository.

Requirements
--------------
- Elasticsearch 1.4
- Perl 5.18+
- Java 7+

Install Elasticsearch on Ubuntu (14.04)
--------------
Reference: http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/setup.html

    sudo apt-get update
    sudo apt-get install python-software-properties
    sudo apt-get install add-apt-repository
    sudo apt-get install software-properties-common
    sudo add-apt-repository ppa:webupd8team/java
    sudo apt-get update
    sudo apt-get install oracle-java7-installer
    sudo apt-get install elasticsearch
    sudo update-rc.d elasticsearch defaults 95 10
    sudo /etc/init.d/elasticsearch start
    curl -XGET localhost:9200/ (to check it is running)
    sudo cd /usr/share/elasticsearch
    sudo bin/plugin -install mobz/elasticsearch-head
    sudo bin/plugin -install elasticsearch/elasticsearch-mapper-attachments/2.4.1
    sudo /etc/init.d/elasticsearch restart

Create index and mapping
--------------
On local Windows machine
- Navigate to http://elasticsearchIP:9200/_plugin/head/ to browse the contents of Elasticsearch
- Navigate to http://sense.qbox.io/gist/ to issue commands against Elasticsearch
- Change ip address to that of Elasticsearch server
- Issue the following to create an index with the relevant fields

```json
PUT /lti
{
"settings" : { "index" : { "number_of_shards" : 1, "number_of_replicas" : 0 }},
 "mappings" : {
  "_default_" : {
   "properties" : {
    "date" : {"type": "string", "index" : "not_analyzed" },
    "title" : {"type": "string", "index" : "not_analyzed" },
    "url" : {"type": "string", "index" : "not_analyzed" },
    "description" : { "type" : "string" },
    "duration" : { "type" : "string" },
    "file" : { 
        "type" : "attachment", 
        "path": "full",  
        "fields": {
          "title": {"store": "yes"},
          "file" : {"term_vector": "with_positions_offsets", "store": "yes"},
          "content_type": {
            "type": "string",
            "store": true
          }
        }
    }
   }
  }
 }
}
```

Add test document
--------------
Issue the following to check a document is added to the index:

```json
PUT /lti/en/1
{
    "date": "2013/05/23",
    "title": "What is The Venus Project?",
    "url": "http://www.youtube.com/watch?v=mX6Y0D8WACA",
    "description": "A dynamic text video explaining TVP in 83 seconds",
    "duration": "1:23",
    "file" : "77u/MQowMDowMDowMCwwOTMgLS0+IDAwOjAwOjA0LDAzOApXaGF0IGlzIFRoZSBWZW51cyBQcm9qZWN0PwoKMgowMDowMDowNCwxNzggLS0+IDAwOjAwOjA3LDUzMgpUaGUgVmVudXMgUHJvamVjdCBvZmZlcnMgYSBuZXcgc29jaW8tZWNvbm9taWMgc3lzdGVtIHRoYXQgaXNuJ3Q6CgozCjAwOjAwOjA3"
}
```

Query Elasticsearch
--------------
Issue the following to see what is in Elasticsearch:
```json
POST _search
{
   "query": {
      "match_all": {}
   }
}
```

Issue the following to search for the word socio (the word will be found in the attachment content):

```json
POST /_search?pretty=true
{
  "fields" : ["title"],
  "query" : {
    "query_string" : {
      "query" : "socio"
    }
  },
  "highlight" : {
    "fields" : {
      "file" : {}
    }
  }
}
```

Issue the following to search for the word humanity (there will be no results):
```json
POST /_search?pretty=true
{
  "fields" : ["title", "description"],
  "query" : {
    "query_string" : {
      "query" : "humanity"
    }
  },
  "highlight" : {
    "fields" : {
      "file" : {}
    }
  }
}
```

Delete index 
--------------
Issue the following to delete the lti index and test document:

```json
DELETE /lti
```

Re-create index 
--------------
Re-create the lti index and mapping (as before).

Set up script importVideos.pl
--------------

Pre-requisites for the the main script on Ubuntu
    
    sudo apt-get install libhtml-tableextract-perl
    sudo apt-get install libwww-perl
    sudo apt-get install libjson-perl
    sudo apt-get install libhtml-tokeparser-simple-perl
    sudo apt-get install libfile-slurp-perl
    sudo apt-get install cpanminus
    sudo cpanm WWW::JSON
    sudo cpanm String::Util

Copy over importVideos.pl script (755 permissions)

Import data 
--------------
Then run by 
    perl importVideos.pl elasticsearchIP workingPath

This should import the records from the official repository. An index (equivalent to a database) containing data for 158 videos will take up about 15MB. 

Re-query Elasticsearch 
--------------
Re-issue the keyword searches and you should get a few more results.

