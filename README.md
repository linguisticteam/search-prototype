search-prototype
================

Search server prototype using data from LTI's official repository.

Requirements
--------------
- Elasticsearch 5.4
- Perl 5.24.1
- openjdk 1.8.0


Install Elasticsearch on Ubuntu (17.04)
--------------
Reference: https://www.elastic.co/guide/en/elasticsearch/reference/current/_installation.html

    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
    sudo apt-get install apt-transport-https
    echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list
    sudo apt-get update && sudo apt-get install elasticsearch
    sudo apt-get install curl
    sudo cd /usr/share/elasticsearch
    sudo apt install git
    git clone git://github.com/mobz/elasticsearch-head.git
    sudo git clone git://github.com/mobz/elasticsearch-head.git
    cd elasticsearch-head
    sudo apt-get install docker
    sudo docker install
    sudo apt install docker.io
    sudo docker run -p 9100:9100 mobz/elasticsearch-head:5 &
    sudo ufw allow 9100
    sudo apt-get update && sudo apt-get install kibana
    sudo bin/elasticsearch-plugin install ingest-attachment
    sudo /bin/systemctl daemon-reload
    sudo /bin/systemctl enable elasticsearch.service
    sudo systemctl status elasticsearch.service
    sudo ufw allow 9200
    sudo vi /etc/elasticsearch/elasticsearch.yml
        and add the following:
        network.host: 0.0.0.0
        http.cors.enabled: true
        http.cors.allow-origin: /.*/  
        http.cors.allow-credentials: true
    sudo systemctl start elasticsearch.service
    sudo systemctl status elasticsearch.service
    tail -f /var/log/elasticsearch/elasticsearch.log
    curl -XGET localhost:9200/
    sudo /bin/systemctl enable kibana.service
    sudo vi /etc/kibana/kibana.yml
        and add the following:
        server.host: "0.0.0.0"
    sudo systemctl status elasticsearch.service
    sudo systemctl start kibana.service
    sudo systemctl status kibana.service
    sudo ufw allow 5601
    sudo ufw status 
    
Create index and mapping
--------------
On local Windows machine
- Navigate to http://elasticsearchIP:9200/_plugin/head/ to browse the contents of Elasticsearch
- Navigate to http://sense.qbox.io/gist/ to issue commands against Elasticsearch
- Change ip address to that of Elasticsearch server
- Issue the following to delete and create the ingest attachment pipeline

```json
DELETE _ingest/pipeline/attachment
PUT _ingest/pipeline/attachment
{
  "description" : "Extract attachment information",
  "processors" : [
    {
      "attachment" : {
        "field" : "file",
        "indexed_chars": -1
      }
    }
  ]
}
```

- Issue the following to delete and create an index with the relevant fields

```json
DELETE /lti
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
    "duration" : { "type" : "string" }
   }
  },
  "document": {
        	"properties": {
				"file": {
					"type": "text"
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
PUT /lti/en/1?pipeline=attachment
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

Issue the following to search for the word "socio" (the word will be found in the attachment content):

```json
POST /_search?pretty=true
{
  "query" : {
    "query_string" : {
      "query" : "socio"
    }
  },
  "highlight" : {
    "fields" : {
          "attachment.content": {
				"fragment_size": 150,
				"number_of_fragments": 3,
				"no_match_size": 150
			}
    }
  }
}
```

Issue the following to search for the phrase "socio-economic system":
```json
POST /lti/en/_search?pretty=true
{
  "_source": {
      "includes": [ "title" ],
      "excludes": [ "file" ]
  },
  "query" : {
      "match_phrase": {
         "attachment.content": "socio-economic system"
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
    e.g. sudo perl importVideos.pl localhost /tmp

This should import the records from the official repository. An index (equivalent to a database) containing data for 304 videos will take up about 40MB. 

Re-query Elasticsearch 
--------------
Re-issue the keyword searches and you should get a few more results.

Miscellaneous
--------------

From Windows to check if can access ports, start Powershell and issue the following commands, modifying the port as appropriate:

$t = New-Object Net.Sockets.TcpClient "192.168.19.29", 9200
$t.Connected

If you want to make the health of the cluster green, update the number of replicas to 0 for the kibana index:

PUT /.kibana/_settings
{
    "index" : {
        "number_of_replicas" : 0
    } }

Other references:
https://stackoverflow.com/questions/37861279/how-to-index-a-pdf-file-in-elasticsearch-5-0-0-with-ingest-attachment-plugin
https://discuss.elastic.co/t/implementing-ingest-attachment-processor-plugin/52300/24
https://discuss.elastic.co/t/cannot-access-kibana-remotely/45363/2
https://github.com/mobz/elasticsearch-head/blob/master/README.textile