date "+Compiled: %Y/%m/%d %H:%M:%S" > version.txt
rm ../CHORDiUM.love
zip -9 -r -x\.git/* ../CHORDiUM.love .