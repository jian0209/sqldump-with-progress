# sqldump-with-progress
This is the script that support progress bar, while you are using mysql database, and have to dump the data.

## Description
- Using pv `sudo apt-get install pv` to show the progress bar when dumping the sql data.
- Supported base64 decryption, and no password showing, make mysqldump more secure.
- The safety process and if you are lazy to type password everytime, you can use `./script.sh --decryption < pwd.txt`.

## Add to var
`echo "alias [YOUR_VAR_NAME](eg: sqldump_with_progress) = '/YOUR_PATH/script.sh'" >> ~/.bashrc`

### For more details, `./script.sh --help | -h`
