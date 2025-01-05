# THIS BRANCH IS REQUIRED FOR Updater SUPPORT TO WORK!

This is necessary because (currently at line 265 of p4sstime.sp) the URL to the updatefile is hardcoded to this endpoint:
```cpp
public void OnLibraryAdded(const char[] name)
{
  if (StrEqual(name, "updater"))
  {
    Updater_AddPlugin(
      "https://raw.githubusercontent.com/p4sstime/p4sstime-server-resources/refs/heads/updater/updatefile.txt");
  }
}
```
