# mikrotik

Mikrotik RouterOS configuration.

#### Picocom:

```
sudo picocom -b 115200 /dev/ttyUSB0
```

Use `Ctrl-a` + `Ctrl-x` to exit.

#### Upload files:

Enable the `ftp` service:

```
/ip service enable ftp
```

Transfer the file:

```
curl -sT config.rsc ftp://192.168.1.1 --user user:pass
```

Conveniently:
```
./bin/upload RB493G/config.rsc
```

#### Reset and load:

```
/system reset-configuration keep-users=yes no-defaults=yes skip-backup=yes run-after-reset=config.rsc
```

If config is not loaded after restart try...
```
/import config.rsc
```

...or add a dirty delay in the script:
```
:delay 15s
```

#### Downgrade:

Upload `.npk` files for the previous version you would like to downgrade to then run:
```
/system package downgrade
```
