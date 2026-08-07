
## fr9009 zc706_v1 构建说明

### 目录约定

- HDL 源码目录：`./src`
- 约束目录：`./constraints`
- 工程入口脚本：`./system_project.tcl`

### 一键构建 Vivado 工程

在 `projects/fr9009/zc706_v1` 目录执行：

```bash
make
```

可先做命令预览（不实际运行 Vivado）：

```bash
make -n
```

### 主要输出文件

- Vivado 工程：`./fr9009_zc706_v1_prj.xpr`
- XSA 导出：`./fr9009_zc706_v1_prj.sdk/system_top.xsa`
- bit 文件：`./fr9009_zc706_v1_prj.runs/impl_1/system_top.bit`
- 构建日志：`./fr9009_zc706_v1_prj_vivado.log`

### 清理命令

删除当前工程构建产物：

```bash
make clean
```

同时清理依赖库构建产物（更彻底）：

```bash
make clean-all
```

---


241024：
		添加rx抓取功能
		cfg_0[6]：上升沿抓数;
		数据起始地址：0x4000000， 长度：256Kbytes
		ddr data paly 的最大长度是2**23bytes,默认长度为8192

241021：
		DDS配置：
		cfg_0[1:0] --- 置1，配置使能，置0，配置禁用
		cfg_1[31:0] --- dds0 频率控制字
		cfg_2[31:0] --- dds0 相位控制字
		cfg_3[31:0] --- dds1 频率控制字
		cfg_4[31:0] --- dds1 相位控制字
		
		信源选择 cfg_0[3:2]
			  00：DDS, 01:DDR, 11:[cfg_5,cfg_6]
		maper选择：cfg_0[4]
				0: 491.52MHz，1：245.76MHz
		
		ddr data paly:
				cfg_0[5]: 上升沿播放。
				cfg_7[31:0],播放长度配置，最高位写1配置被写入。
		删除VIO数据入口。	    

240926：
		TX1/2 DDS信源分开；
		DDS频率可配置:
					addr:0x43C30000 [1:0] 分别控制tx1/2的DDS config_tvalid，配置频率时需要置1
					addr:0x43C30004 配置tx1的DDS 频率， pinc = 2^30*freq/refclock,refclock=245.76MHz
					addr:0x43C30008 配置tx2的DDS 频率， pinc = 2^30*freq/refclock,refclock=245.76MHz
		tx mapper mode 修改为寄存器配置：
					addr:0x43C3000C [0] 1为vio数据，0为DDS数据
		jesd_phy linerate 修改为动态配置模式，可用范围[6-10],默认为9.8304GHz，
240910：
		add mapper demapper

240909：
vivado version:2019.2

JESD Config : lanerate 9.8304GHz，Core Clock and refclock = 245.76MHz
			  default L=4,F=4,K=32

TXData: VIO(vio_s)=0,TXData = viodata;
		VIO(vio_s)=1,TXData = DDS data;
		
DDS Config: default frequency 10MHz,  
			lane0/2 data = DDS 0
			lane1/3 data = DDS 1

fr9009_rst = gpio_0;
ad9525_rst = gpio_1;
ad9582_req = gpio_4;
jesd_rx_rst = gpio_5;
jesd_tx_rst = gpio_6;
