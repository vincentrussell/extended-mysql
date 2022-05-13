FROM mysql:8.0.29


COPY extended-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/extended-entrypoint.sh /extended-entrypoint.sh # backwards compat
ENTRYPOINT ["extended-entrypoint.sh"]
CMD ["mysqld"]