"""Run the packaged checker and write a readable Chinese summary."""
import sys
sys.dont_write_bytecode = True
import argparse
import json
from pathlib import Path
from audit_evidence import audit


def explain(reason):
    descriptions = {
        'Require one RESULT=PASS and explicit zero ERRORS': '结果必须只有一条 RESULT=PASS，且明确记录 ERRORS=0。请检查测试是否真正完成。',
        'Setup/hold/pulse timing requirements not met': '存在建立、保持或脉宽时序违例，请查看对应 timing.rpt。',
        'Clock period differs from configured requirement': '报告中的时钟周期与配置不同。',
        'Design name does not match configured top': '报告里的顶层模块名与配置不同。',
        'Require Design State: Routed': '这不是完成布局布线后的 Routed 报告。',
        'Configured clock missing from Clock Summary': '没有找到配置指定的时钟，请核对时钟名与报告格式。',
        'Unsupported or incomplete timing summary table': '时序汇总表格式不受支持或数据不完整。',
        'Top instance or supported hierarchical utilization table missing': '没有找到顶层资源行，请使用层级资源报告并核对顶层名。',
    }
    if reason.startswith('Resource budget exceeded: '):
        return '资源超过配置上限：' + reason.split(': ', 1)[1]
    return descriptions.get(reason, reason)


def main():
    skill = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=skill.parent)
    parser.add_argument('--config', type=Path)
    args = parser.parse_args()
    config = args.config or (skill/'configs/my_project.json' if (skill/'configs/my_project.json').exists()
                             else skill/'configs/three_qzs_open.json')
    try:
        result = audit(args.project_root.resolve(), json.loads(config.read_text(encoding='utf-8-sig')))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('无法开始检查：' + str(error))
        print('请检查 Python 版本、配置文件路径与 JSON 格式。')
        return 2
    passed = sum(x['status']=='pass' for x in result['tests'])
    implementations = sum(x['status']=='pass' for x in result['implementations'])
    lines = ['FPGA 仿真与实现结果检查',
             '工程目录：' + str(args.project_root.resolve()), '使用配置：' + str(config.resolve()), '',
             f'仿真结果文件：{passed}/{len(result["tests"])} 组通过检查',
             f'实现报告：{implementations}/{len(result["implementations"])} 套通过检查', '']
    for test in result['tests']:
        lines.append(('通过' if test['status']=='pass' else '失败') + ' | ' + test['name'] + ' | ' + test['path'])
        if test.get('reason'):lines.append('  原因：' + explain(test['reason']))
    lines.append('')
    for item in result['implementations']:
        lines.append(('通过' if item['status']=='pass' else '失败') + ' | 实现配置 ' + item['name'])
        if 'timing' in item:
            t=item['timing'];lines.append(f'  建立裕量 WNS={t["wns_ns"]} ns；保持裕量 WHS={t["whs_ns"]} ns')
        if 'resources' in item:
            r=item['resources'];lines.append(f'  LUT={r["lut"]}，FF={r["ff"]}，RAMB36={r["ramb36"]}，RAMB18={r["ramb18"]}')
        if 'clock_mhz' in item:lines.append(f'  时钟={item["clock_mhz"]} MHz')
        if item.get('reason'):lines.append('  原因：' + explain(item['reason']))
    lines.extend(['', '需要人工查看的提示：'])
    meanings={'TIMING-18':'有输入/输出延时约束缺项', 'LUTAR-1':'LUT 驱动异步复位，需要检查复位结构',
              'no_output_delay':'输出端口未给出延时约束，不能认定外部接口时序已闭合'}
    for warning in result['warnings']:
        lines.append(f'  {warning["implementation"]} | {warning["rule"]} | {warning["count"]} 项 | '+meanings.get(warning['rule'],warning['rule']))
    if not result['warnings']:lines.append('  本脚本识别的提示未检出；其他告警仍需查阅原报告。')
    lines.extend(['', '结论：' + ('所列文件通过检查，请继续处理上述提示。' if result['status']=='pass' else '检查未通过，请按上面的文件和原因排查。'),
                  '这次只读取已有结果，没有重新运行仿真、Vivado 或上板测试。'])
    output=skill/'results';output.mkdir(exist_ok=True)
    summary='\n'.join(lines)+'\n'
    (output/'check_result.txt').write_text(summary,encoding='utf-8-sig')
    (output/'check_result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(summary)
    print('结果已保存：' + str(output/'check_result.txt'))
    return 0 if result['status']=='pass' else 1


if __name__=='__main__':sys.exit(main())
