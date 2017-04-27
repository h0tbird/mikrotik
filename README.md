# mikrotik

Mikrotik RouterOS configuration.

#### Picocom:

```
sudo picocom -b 115200 /dev/ttyUSB0
```

Use `Ctrl-a` + `Ctrl-x` to exit.

#### Reset and load:

```
/system reset-configuration keep-users=yes no-defaults=yes skip-backup=yes run-after-reset=router.rsc
```
