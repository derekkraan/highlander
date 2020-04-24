{_, 0} = System.cmd("epmd", ["-daemon"])
:ok = LocalCluster.start()

ExUnit.start()
