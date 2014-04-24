{% set redis    = pillar.get('redis',   {}) -%}
{% set download_url = redis.get('download_url', 'http://download.redis.io/redis-stable.tar.gz') -%}
{% set version  = redis.get('vesion',  'stable') -%}
{% set root_dir = redis.get('root_dir', '/opt') -%}
{% set home     = redis.get('home',     '/var/lib/redis') -%}
{% set user     = redis.get('user',     'redis') -%}
{% set group    = redis.get('group',    user) -%}

redis-dependencies:
  pkg.installed:
    - names:
      - build-essential
      - python-dev
      - libxml2-dev
      - wget
      - tar

## Get redis
get-redis:
  cmd.run:
    - name: wget {{ download_url }} -O {{ root_dir }}/redis-{{ version }}.tar.gz
    - unless: which redis-server
    - require:
      - pkg: redis-dependencies

untar-redis:
  cmd.wait:
    - cwd: {{ root_dir }}
    - name: tar xzvf {{ root_dir }}/redis-{{ version }}.tar.gz -C {{ root_dir }}
    - watch:
      - cmd: get-redis

make-redis:
  cmd.wait:
    - cwd: {{ root_dir }}/redis-{{ version }}
    - names:
      - make
    - watch:
      - cmd: untar-redis
  file.symlink:
    - name: /usr/bin/redis-server
    - target: {{ root_dir }}/redis-{{ version }}/src/redis-server

redis-cli:
  file.symlink:
    - name: /usr/bin/redis-cli
    - target: {{ root_dir }}/redis-{{ version }}/src/redis-cli
    - require:
      - cmd: make-redis

redis_group:
  group.present:
    - name: {{ group }}
    
redis_user:
  user.present:
    - name: {{ user }}
    - gid_from_name: True
    - home: {{ home }}
    - group: {{ group }}
    - require:
      - group: redis_group
      
redis-dirs:
  file.directory:
    - names:
      - /var/log/redis
      - /etc/redis
    - mode: 755
    - user: {{ user }}
    - group: {{ group }}
    - makedirs: True
    - require: 
      - user: redis_user

redis-conf:
  file.managed:
    - user: {{ user }}
    - group: {{ group }}
    - name: /etc/redis/redis.conf
    - template: jinja
    - mode: 644
    - makedirs: True
    - source: salt://redis/redis.conf.jinja
    - require:
      - file: redis-dirs

redis-server:
  file.managed:
    - name: /etc/init/redis-server.conf
    - template: jinja
    - source: salt://redis/upstart.conf.jinja
    - mode: 0750
    - user: root
    - group: root
    - context:
        run: /usr/bin/redis-server
        conf: /etc/redis/redis.conf
        user: {{ user }}
        group: {{ group }}
    - require:
      - cmd: make-redis
  service:
    - running
    - require:
      - file: redis-conf
      - file: redis-server
