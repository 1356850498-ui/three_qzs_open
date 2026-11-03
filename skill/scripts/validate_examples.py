"""Exercise successful, failing, and portable-input audits without editing project evidence."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    project=args.project_root.resolve()
    spec=importlib.util.spec_from_file_location('evidence_audit',Path(__file__).with_name('audit_evidence.py'))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    config=json.loads((project/'skill/configs/three_qzs_open.json').read_text())
    cases=[]
    # Use the current workspace so the caller controls where temporary writes occur.
    with tempfile.TemporaryDirectory(prefix='skill_check_',dir=Path.cwd()) as directory:
        base=Path(directory)
        assert base.resolve().is_relative_to(Path.cwd().resolve())
        for test in config['tests']:
            dest=base/test['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(project/test['path'],dest)
        for implementation in config['implementations']:
            for key in ['timing','utilization']:
                dest=base/implementation[key];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(project/implementation[key],dest)
        def check(name,cfg,expected):
            outcome=module.audit(base,cfg)
            assert outcome['status']==expected,(name,outcome)
            cases.append({'case':name,'expected':expected,'observed':outcome['status'],'verified':True})
            return outcome
        result=check('saved_project_evidence',config,'pass')
        assert len(result['tests'])==17 and len(result['implementations'])==2
        assert result['implementations'][0]['resources']['lut']==829
        assert result['implementations'][0]['timing']['wns_ns']==1.058
        assert any(w['rule']=='TIMING-18' for w in result['warnings'])
        cfg=copy.deepcopy(config);cfg['tests'][0]['path']='missing/result.txt'
        check('missing_result',cfg,'fail')
        target=base/config['tests'][0]['path'];original=target.read_bytes()
        for name,body in [('incomplete_result','RESULT=INCOMPLETE\nERRORS=0\n'),
                          ('pass_with_nonzero_errors','RESULT=PASS\nERRORS=1\n'),
                          ('pass_without_error_count','RESULT=PASS\n'),
                          ('conflicting_result','RESULT=PASS\nRESULT=FAIL\nERRORS=0\n')]:
            target.write_text(body);check(name,config,'fail')
        target.write_bytes(original)
        cfg=copy.deepcopy(config);cfg['implementations'][0]['period_ns']=20
        check('incorrect_clock_requirement',cfg,'fail')
        cfg=copy.deepcopy(config);cfg['implementations'][0]['top']='other_top'
        check('incorrect_top',cfg,'fail')
        cfg=copy.deepcopy(config);cfg['implementations'][0]['max_resources']={'lut':828}
        check('resource_budget_exceeded',cfg,'fail')
        timing=base/config['implementations'][0]['timing'];original=timing.read_bytes()
        timing.write_bytes((project/'build/reports/pre_carrier_register/main/implementation/timing.rpt').read_bytes())
        check('real_historical_negative_timing',config,'fail')
        timing.write_bytes(original)
        cfg=copy.deepcopy(config);cfg['tests'][0]['path']='../outside_root.txt'
        check('evidence_outside_project_root',cfg,'fail')
        # A deliberately different project shape: one test, one top, 50 MHz, different resource counts.
        (base/'another_design').mkdir()
        (base/'another_design/test.txt').write_text('RESULT=PASS\nERRORS=0\n')
        fixture='''| Design       : controller_top
| Design State : Routed
 WNS(ns) TNS(ns) TNS Failing Endpoints TNS Total Endpoints WHS(ns) THS(ns) THS Failing Endpoints THS Total Endpoints WPWS(ns) TPWS(ns) TPWS Failing Endpoints TPWS Total Endpoints
 ------- ------- --------------------- ------------------- ------- ------- --------------------- ------------------- -------- -------- ---------------------- --------------------
 0.500 0.000 0 20 0.100 0.000 0 20 1.000 0.000 0 20
Clock Waveform(ns) Period(ns) Frequency(MHz)
sys_clk {0.000 10.000} 20.000 50.000
'''
        (base/'another_design/timing.rpt').write_text(fixture)
        (base/'another_design/utilization.rpt').write_text('''| Design       : controller_top
| Design State : Routed
| Instance | Module | Total LUTs | Logic LUTs | LUTRAMs | SRLs | FFs | RAMB36 | RAMB18 |
| controller_top | (top) | 123 | 123 | 0 | 0 | 45 | 1 | 0 |
''')
        cfg={'tests':[{'name':'control','path':'another_design/test.txt'}],
             'implementations':[{'name':'default','top':'controller_top','timing':'another_design/timing.rpt',
                'utilization':'another_design/utilization.rpt','clock':'sys_clk','period_ns':20.0,
                'max_resources':{'lut':200,'ff':100}}]}
        result=check('portable_synthetic_50mhz_controller',cfg,'pass')
        assert result['implementations'][0]['resources']=={'lut':123,'ff':45,'ramb36':1,'ramb18':0}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps({'all_verified':True,'cases':cases,'rtl_simulation_rerun':False,
                                   'hardware_test_run':False},indent=2),encoding='utf-8')
    print('VALIDATION_CASES='+str(len(cases)))
    print('RESULT=PASS')


if __name__=='__main__':main()
