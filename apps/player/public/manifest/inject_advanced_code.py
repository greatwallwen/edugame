"""
inject_advanced_code.py· 轻章节补进阶代码知识点

6 个主实验页只有 1 个 code 块，各补 1 个进阶 STM32 HAL 代码示例，
内容真实（DMA/中断/寄存器进阶用法），拉平章节代码块不均。
幂等。加入 inject_all 管线。
"""
import json, os, sys
try: sys.stdout.reconfigure(encoding='utf-8')
except Exception: pass

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

def code_block(bid, title, code):
    return {'id': bid, 'kind': 'code', 'language': 'c', 'filename': title, 'code': code}

ADV = {
    'p4-timer': code_block('p4-timer-adv', 'tim_pwm_input.c', """\
/* 进阶：定时器输入捕获测量外部脉冲频率 */
void TIM3_IC_Init(void) {
    /* TI1 上升沿捕获，从模式复位 — 自动测周期 */
    HAL_TIM_IC_Start_IT(&htim3, TIM_CHANNEL_1);
    HAL_TIM_IC_Start(&htim3, TIM_CHANNEL_2);
}
void HAL_TIM_IC_CaptureCallback(TIM_HandleTypeDef *htim) {
    uint32_t period = HAL_TIM_ReadCapturedValue(htim, TIM_CHANNEL_1);
    uint32_t freq = (period != 0) ? (1000000UL / period) : 0;  /* 1MHz 计数时钟 */
}"""),
    'p5-pwm': code_block('p5-pwm-adv', 'pwm_breath_dma.c', """\
/* 进阶：DMA 驱动 PWM 占空比，CPU 零干预实现呼吸灯 */
uint16_t breath[200];  /* 预生成正弦占空比表 */
void PWM_Breath_DMA(void) {
    for (int i = 0; i < 200; i++)
        breath[i] = (uint16_t)((1.0f - cosf(2*3.14159f*i/200)) / 2 * htim2.Init.Period);
    HAL_TIM_PWM_Start_DMA(&htim2, TIM_CHANNEL_1, (uint32_t*)breath, 200);
}"""),
    'p7-adc': code_block('p7-adc-adv', 'adc_dma_multi.c', """\
/* 进阶：ADC + DMA 多通道连续采样，环形缓冲 */
uint16_t adc_buf[3];  /* 3 通道：温度/光照/电位器 */
void ADC_DMA_Start(void) {
    HAL_ADC_Start_DMA(&hadc1, (uint32_t*)adc_buf, 3);  /* 扫描模式自动循环 */
}
float to_voltage(uint16_t raw) { return raw * 3.3f / 4095.0f; }"""),
    'p8-dac': code_block('p8-dac-adv', 'dac_sine_dma.c', """\
/* 进阶：DAC + DMA + 定时器触发，输出连续正弦波 */
uint16_t sine[100];
void DAC_Sine_Output(void) {
    for (int i = 0; i < 100; i++)
        sine[i] = (uint16_t)((sinf(2*3.14159f*i/100) + 1) / 2 * 4095);
    HAL_TIM_Base_Start(&htim6);  /* TIM6 触发 DAC 转换 */
    HAL_DAC_Start_DMA(&hdac, DAC_CHANNEL_1, (uint32_t*)sine, 100, DAC_ALIGN_12B_R);
}"""),
    'p10-parking': code_block('p10-parking-adv', 'hcsr04_ic.c', """\
/* 进阶：输入捕获精确测量超声波回响时间（替代轮询） */
volatile uint32_t echo_us;
void HAL_TIM_IC_CaptureCallback(TIM_HandleTypeDef *htim) {
    static uint32_t t_rise;
    if (HAL_GPIO_ReadPin(ECHO_GPIO, ECHO_PIN))  /* 上升沿 */
        t_rise = HAL_TIM_ReadCapturedValue(htim, TIM_CHANNEL_1);
    else                                          /* 下降沿 */
        echo_us = HAL_TIM_ReadCapturedValue(htim, TIM_CHANNEL_1) - t_rise;
}
float distance_cm(void) { return echo_us * 0.017f; }  /* 340m/s ÷ 2 */"""),
    'p11-band': code_block('p11-band-adv', 'mpu6050_step.c', """\
/* 进阶：加速度合矢量峰值检测计步算法 */
uint32_t step_count;
void detect_step(int16_t ax, int16_t ay, int16_t az) {
    static float prev = 0; static uint8_t rising = 0;
    float mag = sqrtf((float)ax*ax + (float)ay*ay + (float)az*az);
    if (mag > prev && mag > 17000) rising = 1;          /* 阈值过滤抖动 */
    else if (mag < prev && rising) { step_count++; rising = 0; }
    prev = mag;
}"""),
}

INSERT_AFTER_KINDS = {'code'}  # 插在已有 code 块之后

# 每个进阶代码块配套讲解（作为 commentary，generate_page_actions 自动生成 speak）
NARRATION = {
    'p4-timer-adv': '进阶一步：用定时器的输入捕获功能测量外部脉冲频率。上升沿触发捕获，读出周期值再换算成频率，这是测速、测频的硬件级方案。',
    'p5-pwm-adv': '更优雅的呼吸灯：预先算好一张正弦占空比表，交给 DMA 自动搬运到比较寄存器，CPU 完全不参与，灯光呼吸丝般顺滑。',
    'p7-adc-adv': '多通道采集的正解：ADC 配合 DMA 扫描模式，温度、光照、电位器三路数据自动写入环形缓冲，主循环只管取用。',
    'p8-dac-adv': '连续波形输出：把正弦查找表交给 DMA，再用定时器触发 DAC 转换，无需 CPU 干预即可产生平滑的模拟信号。',
    'p10-parking-adv': '精确测距的关键：用定时器输入捕获记录超声波回响的上升沿和下降沿时刻，时间差乘以声速一半就是距离，比轮询精准得多。',
    'p11-band-adv': '计步算法核心：计算三轴加速度的合矢量，检测它的周期性峰值，配合阈值过滤抖动，每个有效峰值就是一步。',
}

def main():
    m = json.load(open(MANIFEST, encoding='utf-8'))
    added = 0
    for ch in m['chapters']:
        for s in ch['sections']:
            for p in s['pages']:
                if p['id'] not in ADV: continue
                item = ADV[p['id']]
                if any(b['id'] == item['id'] for b in p.get('blocks', [])): continue
                # 维度3：附 commentary.script，让 generate_page_actions 自动生成 speak
                narr = NARRATION.get(item['id'])
                if narr:
                    item = {**item, 'commentary': {'source': 'script', 'script': narr}}
                idx = len(p['blocks'])
                for i, b in enumerate(p['blocks']):
                    if b.get('kind') == 'code': idx = i + 1; break
                p['blocks'].insert(idx, item)
                added += 1
    json.dump(m, open(MANIFEST, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(f'[adv-code] 补进阶代码块(含讲解): {added} 个')

if __name__ == '__main__':
    main()
