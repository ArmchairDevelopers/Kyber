<h1 align="center"><img src="https://kyber.gg/logo.svg" width="30rem"> Kyber</h1>

<h4 align="center">Kyber is an Open-Source Private Server tool for STAR WARS™ Battlefront™ II (2017).</h4>
<br>
<p align="center">
  <a href="https://twitter.com/BattleDashBR"><img src="https://img.shields.io/badge/Twitter-@BattleDashBR-1da1f2.svg?logo=twitter"></a>
  <a href="https://discord.gg/kyber">
      <img src="https://img.shields.io/discord/305338604316655616.svg?label=Discord&logo=discord&color=778cd4">
  </a>
  
</p>

------

A hosted version of Kyber is available at [kyber.gg](https://kyber.gg), where I operate proxies for server data that alleviate the issue of port forwarding and IP security.

This new open-source rewrite of Kyber is unfinished, as I am busy with work and burnt out after working on this for a while now.

It was my intent to make this public as it was completed, however, I have realized that it would be better to simply open-source the current version
and complete it publicly, as there isn't much left to do. If you want to contribute to the project, please do so! When this version of Kyber is done, an update with it will be rolled out to [kyber.gg](https://kyber.gg), along with a new launcher.

What's done:
* Server starting
* Networking
* Direct proxy support
* NAT Punch-Through system
* In-Game server browser
* Per-player team swapping
* Player kicking/moderation
* Optimal proxy detection

What isn't done:
* Built-in mod verification (currently handled at the proxy level, meaning it's unavailable if you direct-connect)
* Kick messages (currently if you are kicked by the server admin you just get sent back to the menu with no indication of why)
* UX/UI Styling (WIP)
* Player banning
* Database handling at the proxy level

If you want to use Kyber purely without a proxy (port forwarding and having people connect to your IP), the rewrite (this) is completely usable for that, feel free to build Kyber and inject it with the new launcher (/Launcher, will need a few modifications to run your own dll).

This should be out on [kyber.gg](https://kyber.gg) with a proper launcher and everything in the coming weeks, I just don't have the time right now. Feel free to have a look around the code in the meantime!

**Stars and PRs are welcome!**

## Credits

Kyber utilizes the following open-source projects:

- [MinHook](https://github.com/TsudaKageyu/minhook)
- [ImGUI](https://github.com/ocornut/imgui)
- [GLFW](https://glfw.org)
- [cpp-httplib](https://github.com/yhirose/cpp-httplib)
- [openssl](https://openssl.org)
- [executors](https://github.com/chriskohlhoff/executors)
- [nlohmann-json](https://github.com/nlohmann/json)
