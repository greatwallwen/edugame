# -*- coding: utf-8 -*-
"""
inject_narration_p4_p5_p6.py

3 页主讲页 narration 扩写。用 triple-quote 避免 ASCII 双引号在中文里干扰。
所有原本要内嵌的"引用语"统一改用全角中文引号（U+201C / U+201D）。
"""
from __future__ import annotations
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from inject_narration_factory import run as run_narration  # type: ignore


# ─── p4-timer · dh + experiment ─────────────────────────
P4_DH_SCRIPT = """同学们好，这一节我们正式进入定时器的世界。前面 GPIO 让我们学会让灯亮、让按键响应，但要让 STM32 主动地、规律地、精确地干一件事，比如每秒翻一次 LED、每 100 毫秒采一次 ADC、每 20 毫秒输出一次舵机脉冲——这些都得交给定时器去做。CPU 只要把任务描述给定时器（多久一次、做什么），就可以去干别的事，定时器自己掐着表干活。这就是嵌入式里让外设代替 CPU 思想的第一次完整体现。

通用定时器最核心的三件套是 PSC、ARR、CNT。PSC 是预分频系数，把芯片送进来的高频时钟（在我们这块板子上是 72MHz）分到一个我们容易计算的频率上；ARR 是自动重装载值，决定计数器从 0 数到多少就溢出一次；CNT 是当前计数值，每个时钟周期 +1。三个加起来给我们一个简单到不能再简单的公式：溢出周期 = (ARR + 1) / (CK_CLK / (PSC + 1))。想要 1ms 中断一次？PSC=71 把 72MHz 分到 1MHz，ARR=999，每数到 1000 就溢出。背下这个公式，STM32 定时器你已经掌握了 60% 了。

另一个新手常踩的坑是 APB 总线的倍频陷阱。教材上写 TIM2~5 挂在 APB1，频率 36MHz；但 STM32F1 内部有一条隐含规则：当 APB 分频不为 1 时，定时器时钟自动倍频成 APB 的 2 倍，也就是 72MHz。所以你按 36MHz 算定时器，结果实测周期会是预期的一半，调试三小时找不出问题——这是嵌入式新人入门定时器最常见的魔鬼细节。记住定时器倍频后等于 72M 就基本不会再踩。

最后说说回调。定时器中断的入口是 HAL_TIM_PeriodElapsedCallback，多个 TIM 共用这个回调时，必须用 if(htim->Instance == TIM2) 区分。这就是为什么 HAL 库的回调函数都要带 htim 参数——它告诉你这次是谁在叫你。配合 ISR 铁律极短、不阻塞、不调慢函数，你写的回调代码就能在 STM32 里以微秒级精度运行十年不出事。"""

P4_EXP_STEP_SCRIPTS = [
    """实验目标我们分四步走。第一步搭建最简定时器中断：用 TIM2 做 1 秒周期，在中断回调里翻转 PC13 上的 LED。把这一步跑通你就完整理解了定时器的设置→启动→中断→回调全链路。CubeMX 里点开 Timers 把 TIM2 的 Clock Source 改成 Internal Clock，Prescaler 填 7199 把 72MHz 分到 10kHz，Counter Period（这就是 ARR）填 9999 让 1 秒溢出一次。再去 NVIC Settings 标签把 TIM2 global interrupt 那一行打勾。Generate Code 后回到 main.c。""",
    """第二步在 main.c 里调 HAL_TIM_Base_Start_IT(&htim2) 启动中断模式定时器。少了这一行，定时器虽然在数，但不会发中断——这是新手最常见的代码看起来都对就是不响陷阱。然后在 main.c 末尾（USER CODE BEGIN 4 区）写 HAL_TIM_PeriodElapsedCallback 回调，里面只有一行 HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13)。烧录运行，PC13 的板载 LED 应该精确以 1 秒频率闪烁。用万用表频率档测一下，应该看到 0.5Hz（一开一关算一周期）。""",
    """第三步实战软件多周期任务调度。把 TIM2 的周期改成 1ms（PSC=71、ARR=999），在回调里加一个静态计数变量 cnt：cnt 自增；如果 cnt 等于 500 就翻 LED1；如果 cnt 等于 1000 就翻 LED2 并把 cnt 清零。这样你只用一个 TIM2 就同时调度了 500ms 和 1s 两个周期任务。工程上一个基础时基加软件计数是节省定时器外设的标准做法——F103 总共就 4 个通用定时器，能省一个是一个。""",
    """第四步排错与精度验证。用示波器或逻辑分析仪把 GPIO 翻转引脚接上，测量周期看是否真的等于公式算出来的值。如果周期偏差大于 1%，先查 PSC/ARR 是否被覆盖、再查 APB 倍频是否生效、最后查 NVIC 是否被更高优先级中断长期阻塞。如果中断完全不响应，按这个顺序排查：① HAL_TIM_Base_Start_IT 调了吗？② NVIC 里 TIM2 中断使能了吗？③ 回调函数名拼写对吗？这三步覆盖 95% 的定时器中断不工作问题。""",
]

P4_NARRATION = {
    'p4-timer-dh': {'kind': 'digital-human', 'script': P4_DH_SCRIPT},
    'p4-timer-exp': {'kind': 'experiment', 'commentary': {'stepScripts': P4_EXP_STEP_SCRIPTS}},
    'p4-timer-code': {'kind': 'code', 'commentary': {'stepScripts': [
        """这段代码示范了定时器中断的最简写法。开头 main 函数里调一次 HAL_TIM_Base_Start_IT(&htim2) 启动 TIM2 的中断模式定时器；这一行是开关，没它定时器虽然在数但不会中断 CPU，是新手 90% 的"代码看起来都对就是不响"陷阱根因。""",
        """中间的 while(1) 主循环里只有一行 HAL_Delay(100) 占位——真实工程里这里跑你的业务逻辑。重点是定时器中断不依赖主循环——主循环就算被堵死，定时器中断仍然按时触发。这种异步性就是定时器最大价值所在。""",
        """末尾的 HAL_GPIO_TogglePin 是回调里唯一一行干活的代码。回调函数名 HAL_TIM_PeriodElapsedCallback 是 HAL 库规定好的，必须严格匹配——拼错一个字母 HAL 链接器会用默认空实现替代你的代码，又是一个隐形坑。多个 TIM 共用回调时要用 if(htim->Instance == TIM2) 区分，否则不同 TIM 的事件会都跑同一段业务逻辑。""",
    ]}},
}


# ─── p5-pwm · dh + experiment ───────────────────────────
P5_DH_SCRIPT = """同学们好，这一节我们玩 PWM——脉冲宽度调制。它是嵌入式里数字信号控制模拟量的最优雅方案。想想看：MCU 的 GPIO 只能输出 0 和 3.3V 两种电平，按理说没办法让 LED 半亮、让电机半速、让舵机转 45 度。但只要让 GPIO 在 0 和 3.3V 之间快速切换，切换得足够快（典型 1kHz 以上），器件本身（LED 的视觉暂留、电机的电感惯性、舵机的内部积分）就会把这个方波平均化成一个介于 0 到 3.3V 之间的等效电压。这就是 PWM 的全部秘密。

PWM 的两个关键参数是频率和占空比。频率是每秒切换多少个完整周期，占空比 D 等于高电平时间除以周期长度。50% 占空比相当于等效 1.65V；20% 占空比相当于等效 0.66V。公式 V_avg = VCC × D 把数字世界和模拟世界连了起来。频率怎么选？要看负载：LED 呼吸灯 200Hz 到 1kHz 就够了；舵机标准 50Hz；DC 电机调速 1kHz 到 20kHz；无刷电机 / 开关电源建议大于等于 20kHz，避开人耳可听噪声。

STM32 生成 PWM 不需要 CPU 干活——配好定时器外设后，硬件自己输出。原理是定时器加输出比较：CNT 持续递增到 ARR 就溢出，每个周期 CNT 的值会和 CCR 寄存器比较，CNT 小于 CCR 时输出高、CNT 大于等于 CCR 时输出低。所以 D 等于 CCR 除以 (ARR+1) 就是占空比。想动态调节亮度只要改 CCR 就行，调用 __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, ccr) 即可。这是 STM32 PWM 唯一正确的运行时调节方法——直接写 TIM2->CCR1 寄存器有 preload latch 风险，不推荐。

PWM 输出引脚必须配置成 AF_PP（复用推挽）。这是 STM32 GPIO 模式的鸭子模式——看起来像普通输出，实际控制权交给了 TIM 外设。如果你不小心配成了 OUTPUT_PP，GPIO 就会霸占输出权，TIM 的 PWM 信号根本到不了引脚。这是 PWM 调试第一坑，用示波器测引脚一直是低或高就先排查这个。"""

P5_EXP_STEP_SCRIPTS = [
    """实验目标分四步走。第一步用 TIM2 通道 1（对应 PA0）输出 50% 占空比 1kHz 方波。CubeMX 里把 PA0 设为 TIM2_CH1，GPIO Mode 自动变成 AF_PP；TIM2 的 Prescaler=71（72MHz / 72 = 1MHz 计数频率），Counter Period=999（1MHz / 1000 = 1kHz）；PWM Generation Channel 1 那一栏 Pulse 填 500，CCR=500 / (999+1) = 50% 占空比。""",
    """第二步生成代码后在 main.c 调 HAL_TIM_PWM_Start(&htim2, TIM_CHANNEL_1) 启动 PWM。这一步少了 PWM 不会输出，和上一节定时器中断要调 Start_IT 是一个道理。烧录运行，用示波器接 PA0 应该看到稳定 1kHz 的方波，高电平 500us、低电平 500us，幅值 3.3V。用万用表直流档测应该是 1.65V——这就是数字 PWM 平均化成模拟电压的实证。""",
    """第三步动手做呼吸灯。把 LED 接到 PA0（串 220Ω 限流电阻），在 while(1) 里写一个 for 循环让 ccr 从 0 渐变到 999 再渐变到 0，每改一次调 __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, ccr) 把新占空比写进去，再 HAL_Delay(2) 让肉眼能看出渐变。LED 应该呈现由暗到亮再由亮到暗的呼吸效果。如果不平滑，可以把 ccr 走 sin² 曲线代替线性递增——人眼对暗处更敏感，sin² 曲线会让呼吸看起来更顺。""",
    """第四步驱动舵机。SG90 舵机要求 50Hz PWM，0.5ms 到 2.5ms 高电平脉宽对应 -90 度到 +90 度。重新算定时器：PSC=71（1MHz 计数频率），ARR=19999（1MHz / 20000 = 50Hz、20ms 周期）。中位 1.5ms 对应 CCR=1500；写 SetCompare 调用扫 CCR 从 500（最左）到 2500（最右），舵机会跟着走。注意舵机供电要用 5V 外接电源，不能从 STM32 USB 供电——舵机瞬间电流 200 到 500mA 会拖崩 USB 5V，导致 MCU 复位甚至电脑 USB 端口断电。""",
]

P5_NARRATION = {
    'p5-pwm-dh': {'kind': 'digital-human', 'script': P5_DH_SCRIPT},
    'p5-pwm-exp': {'kind': 'experiment', 'commentary': {'stepScripts': P5_EXP_STEP_SCRIPTS}},
    'p5-pwm-code': {'kind': 'code', 'commentary': {'stepScripts': [
        """代码顶端的 HAL_TIM_PWM_Start 启动 PWM 输出。和定时器中断 Start_IT 类似，PWM 也必须主动启动——CubeMX 配置只是"准备好硬件"，真正让信号出来要靠这一行。如果烧录后 PA0 一直是低电平或高电平，第一个排查点就是这里。""",
        """中段的 __HAL_TIM_SET_COMPARE 是 PWM 调节的灵魂接口。它把新的 CCR 值写进定时器，下一个周期立刻生效——这就是呼吸灯每 2ms 平滑过渡的关键。直接写 TIM2->CCR1 寄存器看似等价，但有 preload latch 风险——某些工作模式下新值要等下一次 update event 才锁存，导致 1 个周期的乱跳。务必走 HAL 接口。""",
        """末尾的 for 循环把 ccr 从 0 到 999 再回到 0，每次 HAL_Delay(2) 让肉眼跟得上变化——一次完整呼吸约 4 秒。如果想让呼吸更"自然"，把 ccr 走 sin² 曲线（人眼对低亮度更敏感，线性会显得"中间快两端慢"）。这就是工业级呼吸灯产品和 demo 的差距所在。""",
    ]}},
}


# ─── p6-uart · dh + experiment + animation ─────
P6_DH_SCRIPT = """同学们好，这一节我们打开 STM32 通信能力的第一扇门——UART 异步串口。在嵌入式系统里，通信听起来高大上，但 UART 是最朴素的：两根线（TX 发、RX 收）加一根公共地线，三根线就能让两个芯片或一台电脑和一颗 MCU 互相说话。工业现场的传感器读数、调试时的 printf 日志、和上位机的命令交互、和蓝牙模块、4G 模组通信——底层全是 UART。把 UART 玩透，你的嵌入式开发成本会立刻降一大截。

8N1 是 UART 最常见的格式：1 起始位 + 8 数据位（LSB 先）+ 0 校验 + 1 停止位 = 10 bit / byte。波特率（baud rate）就是每秒能传多少 bit。常用值：调试用 115200（8.68us / bit），ESP8266 默认 9600，蓝牙 HC-05 默认 9600，工业 Modbus 9600 或 19200。两端波特率必须一致——差 1% 以内能正常通信，超过 5% 就开始乱码。这是 UART 调试第一个排查点：示波器或逻辑分析仪测一下 TX 实际频率，对比配置值。

STM32 的 UART 三种模式各有适用场景。HAL_UART_Transmit / Receive 是阻塞同步：CPU 卡在那儿等，不能干别的事——只适合调试和偶发命令；HAL_UART_Transmit_IT / Receive_IT 是中断模式：硬件每收 / 发 1 字节中断 CPU 一次，CPU 在中断里 1us 处理完就回主循环，主循环可以做别的事；HAL_UART_Transmit_DMA / Receive_DMA 是 DMA 模式：硬件直接把整段数据搬进 / 搬出内存，CPU 完全不参与，搬完才中断一次——适合高速大块通信，比如 1Mbps 数据流采集。

工程上的黄金范式是 DMA 加 IDLE 中断处理变长帧。DMA 把收进来的字节自动堆到环形缓冲，硬件检测到 RX 线空闲超过 1 个字节时间就触发 IDLE 中断，中断里读出这一帧的长度告诉主循环一帧来了，主循环再去解析。这个范式在工业控制、IoT 网关、BLE 网关等场景几乎是标准答案，背下来你就能写工业级的串口协议栈。"""

P6_EXP_STEP_SCRIPTS = [
    """实验目标第一步建立 PC 和 STM32 互通。CubeMX 里启用 USART1 ASYNC 模式、波特率 115200、8N1。物理接线：USB 转 TTL 模块的 TX 接 STM32 的 PA10（USART1_RX），RX 接 PA9（USART1_TX）；公共地线必须接，否则双方电压参考点不同会乱码。Generate Code 后写一个简单循环：HAL_UART_Transmit 每秒发一行 Hello STM32 字符串加换行符，电脑端用 SecureCRT 或 putty 打开对应 COM 端口、115200 波特率，应该看到稳定输出。""",
    """第二步加上 printf 重定向。在 main.c 包含 stdio.h，重写 _write 函数（gcc 编译器使用 syscalls.c）或 fputc（Keil 编译器），里面调 HAL_UART_Transmit 把每个字符发出去。之后所有 printf 比如 ADC=%d 这样的格式都会出现在串口助手上。这是最常用的嵌入式调试手段——比 LED 闪、示波器测都高效，可以打印任何变量值、运行状态。记住一个细节：printf 输出会一定程度上拖慢主循环，正式产品里用宏开关 DEBUG_LOG。""",
    """第三步切到中断接收模式。重写 HAL_UART_RxCpltCallback：判断 huart->Instance 是否等于 USART1，若是则把 rxByte 存入全局变量、置位 g_rxFlag=1、再次调 HAL_UART_Receive_IT 把接收重启。最后这一步重新调 Receive_IT 是关键——HAL 的 _IT 接口是一次性的，Callback 不重启就只能收一帧。在 main 里先调一次 Receive_IT 启动接收，然后主循环 polling g_rxFlag，发现置位就处理 rxByte 并清 flag。电脑端发任何字符 STM32 都该立刻 echo 回来。""",
    """第四步实战 LED 命令解析。设计一个最简协议：电脑发 LED ON 加换行 STM32 点灯、发 LED OFF 加换行 STM32 灭灯。在主循环里收到字符就堆到 ringbuf，看到换行符就把这一帧拷贝到 cmd 数组、用 strncmp 匹配。注意：strncmp 不能放 ISR 里——它的执行时间不确定，可能是几十个时钟周期到几百个；ISR 里只置标志、堆缓冲，复杂解析全部在主循环。这就是 ISR 铁律最好的实战教学案例。做到这一步你已经写出了一个迷你串口协议栈，离工程级指令解释器只差几个动作（CRC、超时、重发）。""",
]

P6_ANIM_STEP_SCRIPTS = [
    """我们一帧一帧看 UART 8N1 的物理过程。最左边的灰色区域是空闲态——TX 线由内部上拉拉到高电平 1，持续无数 bit 时间。接收方靠线一直是高判断现在没数据。一旦发送方想发一个字节，第一步就是把 TX 拉低，制造一个清晰的下降沿。""",
    """下降沿就是起始位 START。它持续整整 1 个 bit 时间。接收方一看到下降沿就启动内部时钟，在 START 的中间（半个 bit 时间后）对一下表，然后每隔 1 个 bit 时间采样一次。这种下降沿同步、自时钟采样机制让 UART 不需要双方共享时钟线，仅靠双方约定的波特率就能通信，这就是它叫异步通信的原因。""",
    """起始位过后是 8 个数据位 D0 到 D7，按 LSB 先发的顺序。注意是 LSB 先而不是 MSB 先——这是 UART 协议的硬性规定，跟人类阅读习惯相反。如果你看波形误以为是 MSB 先，解码出来的字节会全错。示波器和逻辑分析仪默认都是按 LSB 先解，所以工具读出来直接对就行，但手算波形要时刻提醒自己这一点。""",
    """数据位之后可选一个奇偶校验位 PARITY。8N1 中那个 N 就是 None 等于没校验，所以这一位被跳过。8E1 是偶校验、8O1 是奇校验，工业现场偶尔见。校验位主要用来检测单 bit 错误——数据位里 1 的个数加校验位等于偶数（偶校验）或奇数（奇校验）。传输出错某一 bit 翻转后这个等式就被破坏，接收方能判断这帧错了，但不能纠正。""",
    """最后是停止位 STOP——线被拉回到高电平 1，至少持续 1 个 bit 时间。停止位结束后线又回到 idle 状态，等下一帧的下降沿。STM32 的 UART 实际硬件还会在停止位中间附近做一个帧错误判断：如果此时 TX 异常变低，置位 FE 标志，告诉软件这帧没收完整。整个 8N1 一帧走完就是 10 个 bit 时间——115200 波特率下约 86.8us 一字节，秒速 11520 字节，对感知层、控制层的数据吞吐基本够用了。""",
]

P6_NARRATION = {
    'p6-uart-dh': {'kind': 'digital-human', 'script': P6_DH_SCRIPT},
    'p6-uart-exp': {'kind': 'experiment', 'commentary': {'stepScripts': P6_EXP_STEP_SCRIPTS}},
    'p6-uart-anim': {'kind': 'animation', 'metadata.teacher': {'stepScripts': P6_ANIM_STEP_SCRIPTS}},
    'p6-uart-code': {'kind': 'code', 'commentary': {'stepScripts': [
        """代码顶端定义了 USART1 的发送函数 uart_send。注意第三个参数 0xFFFF 是超时毫秒——HAL_UART_Transmit 是阻塞同步接口，CPU 会卡在这里等到所有字节发完才返回。生产代码不应该用这种长超时；调试可以接受。""",
        """中段的 main 循环用 HAL_GetTick 实现非阻塞 1 秒发送。这种"上次 tick + 间隔"模式比 HAL_Delay 高效得多——CPU 在这秒钟可以处理别的事，到点再发一次。这是嵌入式实时系统主循环的标准范式，比同步阻塞强 100 倍。""",
        """末尾如果你想加 RX 接收，必须切到中断或 DMA 模式——同步 Receive 会让主循环停摆。先调 HAL_UART_Receive_IT(&huart1, &rxByte, 1) 启动一次接收，然后实现 HAL_UART_RxCpltCallback——里面只能置标志、复启接收，绝不能调慢函数（strstr / printf / I2C 阻塞）。这就是嵌入式 ISR 铁律的串口落地。""",
    ]}},
}


PAGE_NARRATIONS = {
    'p4-timer': P4_NARRATION,
    'p5-pwm':   P5_NARRATION,
    'p6-uart':  P6_NARRATION,
}


def main() -> int:
    n = run_narration(PAGE_NARRATIONS, expected_pages=3)
    return 0 if n > 0 else 1


if __name__ == '__main__':
    raise SystemExit(main())
