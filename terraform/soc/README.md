# SOC / Audit Account Terraform

이 Terraform은 핀테크 클라우드 보안 플랫폼에서 **SOC / Audit Account** 영역을 구성한다.

목표는 Production / Development / Staging 계정의 서비스 운영 리소스를 직접 만드는 것이 아니라, 각 계정에서 발생하는 감사 로그와 보안 이벤트를 중앙 수집하고, 규제 준수 상태를 점검하며, Athena로 분석할 수 있는 SOC 기반을 준비하는 것이다.

## 구현 범위

현재 구현된 주요 구성은 다음과 같다.

```text
SOC / Audit Account
├─ Audit VPC
├─ Peering 연결용 Subnet 2a/2c
├─ Route Tables
├─ VPN EC2 (Corp 연결용)
├─ KMS CMK
├─ S3 Buckets
│  ├─ SOC audit log bucket
│  ├─ Staging log bucket
│  ├─ Dev log bucket
│  └─ SOC Athena results bucket
├─ CloudTrail
├─ AWS Config
├─ VPC Flow Logs
├─ Athena / Glue Catalog
├─ AWS Config Managed Rules
├─ EventBridge
├─ SNS Notification
├─ ISMS-P aligned control mapping
├─ Service log intake manifest
└─ Monthly audit report Lambda
```


## SOC 버킷 설계

SOC 계정에는 보안 관제와 감사 목적의 버킷만 둔다.

```text
fin-prod-log-s3
fin-stg-log-s3
fin-dev-log-s3
fin-athena-result-s3
```

### `fin-prod-log-s3`

Production 계정 로그 저장소다.

저장 대상:

- Production CloudTrail
- Production VPC Flow Logs
- Production AWS Config delivery
- Production WAF Logs
- Production ALB Access Logs

Production 계정의 CloudTrail, Config, Flow Logs는 이 버킷으로 적재하도록 연동한다.

CloudWatch Logs 중앙화 방식에서는 Production 계정의 CloudTrail, AWS Config, VPC Flow Logs, 애플리케이션 로그를 각 CloudWatch Log Group에 모은 뒤 `CreateExportTask`로 아래 prefix에 배치 적재한다.

```text
s3://fin-prod-log-s3/cloudwatch-exports/
```

### `fin-stg-log-s3`

Staging 계정 로그 저장소다. 버킷 보안 설정과 로그 적재 권한은 Production 로그 버킷과 동일하게 운영한다.

저장 대상:

- Staging CloudTrail
- Staging VPC Flow Logs
- Staging AWS Config delivery
- Staging WAF Logs
- Staging ALB Access Logs

CloudWatch Logs 중앙화 적재 위치:

```text
s3://fin-stg-log-s3/cloudwatch-exports/
```

### `fin-dev-log-s3`

Development 계정 로그 저장소다. 개발 환경의 CloudWatch Logs export 결과를 별도 버킷으로 분리하여 운영 로그와 감사 조회 범위를 구분한다.

CloudWatch Logs 중앙화 적재 위치:

```text
s3://fin-dev-log-s3/cloudwatch-exports/
```

### `fin-athena-result-s3`

SOC 자체 로그, SOC Athena 조회 결과, compliance 산출물을 저장한다.

SOC 로그 위치:

```text
s3://fin-athena-result-s3/soc-logs/cloudtrail/
s3://fin-athena-result-s3/soc-logs/config/
s3://fin-athena-result-s3/soc-logs/vpc-flow-logs/
```

기본 Workgroup 결과 위치:

```text
s3://fin-athena-result-s3/athena-results/sc-audit/
```

Compliance 산출물 위치:

```text
s3://fin-athena-result-s3/baseline/
s3://fin-athena-result-s3/monthly-audit/
```

## CloudWatch Logs 중앙화 방식

Production, Staging, Development 계정에서는 CloudTrail, AWS Config, VPC Flow Logs, 애플리케이션 로그를 CloudWatch Logs로 먼저 수집한다. SOC 계정의 중앙 Lambda가 EventBridge 일정에 따라 실행되고, 각 계정의 `fin-cloudwatch-export-role`을 AssumeRole 하여 CloudWatch Logs `CreateExportTask`를 생성한다.

```text
Prod CloudWatch Logs → fin-prod-log-s3/cloudwatch-exports/
Stg  CloudWatch Logs → fin-stg-log-s3/cloudwatch-exports/
Dev  CloudWatch Logs → fin-dev-log-s3/cloudwatch-exports/
SOC  CloudWatch Logs → fin-athena-result-s3/soc-logs/cloudwatch-exports/
```

이 SOC Terraform은 중앙 export Lambda, export 대상 S3 버킷, 버킷 정책을 준비한다. 버킷 정책은 `logs.ap-northeast-2.amazonaws.com` 서비스가 지정된 source account와 log group ARN 조건을 만족할 때만 객체를 쓸 수 있도록 제한한다.

워크로드 계정에는 Lambda를 만들지 않는다. 대신 Prod/Stg/Dev 각 계정에 SOC Lambda 실행 Role을 신뢰하는 `fin-cloudwatch-export-role` IAM Role만 필요하다.

## S3 Lifecycle 보관 기준

### 관련 법률

- 금융보안원 「금융분야 클라우드컴퓨팅서비스 이용 가이드(2025 개정)」: 금융회사가 클라우드서비스를 이용할 때 전자금융감독규정, 금융회사의 정보처리 업무 위탁에 관한 규정 등을 준수해야 하며, 클라우드 이용은 정보처리 위탁에 해당할 수 있다. 전자금융사고 발생 시 클라우드 이용만으로 금융회사의 책임이 면제되지 않으므로 금융회사는 CSP가 관계 법령을 준수하도록 관리ㆍ감독해야 한다.
- 전자금융감독규정 제14조의2: 금융회사 또는 전자금융업자가 「클라우드컴퓨팅 발전 및 이용자 보호에 관한 법률」 제2조제3호의 클라우드컴퓨팅서비스를 이용하려면 업무 중요도 평가, CSP 건전성ㆍ안전성 평가, 업무 연속성 계획, 안전성 확보조치, 정보보호위원회 심의ㆍ의결, 보고 및 최신 서류 유지가 요구된다. 고유식별정보 또는 개인신용정보를 클라우드로 처리하는 경우 해당 정보처리시스템을 국내에 설치해야 한다.
- 전자금융감독규정 제23조ㆍ제24조ㆍ제37조의6: 장애ㆍ재해ㆍ전자적 침해에 대비한 업무지속성 확보방안, 백업 또는 재해복구계획, 비상대응훈련, 재해복구전환훈련, 침해사고 대응 및 복구훈련을 요구한다.
- 전자금융감독규정 제12조ㆍ제14조ㆍ제17조: 정보처리시스템 접속 단말의 정당한 사용자 여부 확인 기록, 주요 정보처리시스템 운영매뉴얼ㆍ유지보수관리대장ㆍ책임자명부ㆍ장애상황기록부, 공개용 웹서버의 거래로그 관리 등 정보기술부문 기록 관리 요구가 있다. 다만 전자금융감독규정 자체가 CloudTrail 같은 클라우드 접근 로그의 단일 보관기간을 7년으로 정하지는 않는다.
- 금융회사의 정보처리 업무 위탁에 관한 규정: 수탁자 및 재위탁자 모니터링, 고객정보 보호, 비상계획, 출구전략, 위탁계약 종료ㆍ중단ㆍ변경 시 데이터 반환ㆍ파기, 감독당국 및 내외부 감사인의 조사ㆍ접근권 확보가 필요하다.
- 클라우드컴퓨팅 발전 및 이용자 보호에 관한 법률 제2조: 클라우드컴퓨팅서비스와 이용자 정보의 기본 개념을 정의한다. 금융회사가 상용 퍼블릭 클라우드에 금융 데이터를 저장하는 것 자체를 금지하기보다, 전자금융감독규정 제14조의2와 정보처리 업무 위탁 규정에 따른 절차ㆍ평가ㆍ계약ㆍ보고ㆍ보안조치를 요구하는 구조다.
- 전자금융거래법 제22조제1항: 금융회사등은 전자금융거래기록을 생성하여 5년의 범위 안에서 대통령령이 정하는 기간 동안 보존하여야 한다.
- 전자금융거래법 제22조제2항: 보존기간이 경과하고 금융거래 등 상거래관계가 종료된 경우에는 5년 이내에 전자금융거래기록을 파기해야 한다. 다만 다른 법률상 의무 이행 등 예외가 있다.
- 전자금융거래법 시행령 제12조제1항: 주요 전자금융거래기록은 5년 보존, 일부 소액ㆍ승인 관련 기록은 1년 보존이다. 5년 보존 대상에는 전자금융거래와 관련한 전자적 장치의 접속기록, 전자금융거래 신청 및 조건 변경 사항, 건당 1만원 초과 전자금융거래 기록 등이 포함된다.
- 전자금융거래법 시행령 제12조제2항: 금융회사 또는 전자금융업자와 동일한 전자금융거래기록을 생성ㆍ보존하는 전자금융보조업자는 제12조제1항제1호 각 목의 기록을 3년 보존한다.
- 개인정보 보호법 제21조: 개인정보는 보유기간 경과, 처리 목적 달성 등으로 불필요하게 된 경우 지체 없이 파기하여야 한다. 다만 다른 법령에 따라 보존해야 하는 경우에는 보존할 수 있으며, 이 경우 다른 개인정보와 분리하여 저장ㆍ관리하여야 한다.
- 개인정보의 안전성 확보조치 기준 제8조: 개인정보처리시스템 접속기록은 1년 이상 보관한다. 5만명 이상 개인정보 처리, 고유식별정보 또는 민감정보 처리 등 고위험 조건에 해당하면 2년 이상 보관한다.
- 신용정보의 이용 및 보호에 관한 법률 제20조의2: 개인신용정보는 「개인정보 보호법」 제21조제1항에도 불구하고 금융거래 등 상거래관계가 종료된 날부터 최장 5년 이내에 관리대상에서 삭제해야 한다. 해당 기간 이전에 수집ㆍ제공 등의 목적이 달성된 경우에는 목적 달성일부터 3개월 이내에 삭제해야 한다.
- 신용정보의 이용 및 보호에 관한 법률 시행령 제17조의2: 상거래관계 종료 후 필수적인 개인신용정보는 현재 거래 중인 고객 정보와 분리하고, 접근 가능한 임직원을 지정하는 등 안전하게 관리해야 한다. 필수적이지 않은 개인신용정보는 삭제 대상이다.
- 신용정보업감독규정 별표 4의2: 선택적 신용정보는 상거래관계 종료일부터 3개월 내 삭제하고, 필수적 신용정보는 분리 보관 및 접근제한을 적용하며, 필수적 신용정보 취급 권한부여 및 이용 내역은 최소 3년 기록ㆍ보존한다.
- 전자상거래 등에서의 소비자보호에 관한 법률 시행령 제6조: 계약, 청약철회, 대금결제, 재화 등의 공급에 관한 기록은 5년 보존 대상이다.
- 국세기본법 제85조의3: 거래에 관한 장부 및 증거서류는 국세 법정신고기한 이후 5년간 보존한다. 역외거래 관련 자료는 7년 보존 대상이 될 수 있다.
- 상법 제33조: 상업장부와 영업에 관한 중요서류는 10년, 전표 또는 이와 유사한 서류는 5년 보존 대상이다.
- 통신비밀보호법 시행령 제41조: 전기통신사업자의 통신사실확인자료는 유형에 따라 12개월 또는 3개월 이상 보관한다. 일반 핀테크 서비스 로그 전체에 직접 적용되는 기준은 아니지만, 통신사실확인자료 성격의 접속ㆍ통신 메타데이터를 다루는 경우 별도 검토가 필요하다.
- 특정 금융거래정보의 보고 및 이용 등에 관한 법률: 자금세탁방지, 고객확인, 의심거래 보고 관련 자료는 금융회사 또는 가상자산사업자 해당 여부에 따라 별도 보존ㆍ제출 의무가 적용될 수 있다. 이 Terraform의 S3 lifecycle은 AML 원본 자료 저장소가 아니라 SOC 감사 로그 저장소 기준이다.

### 금융 데이터를 퍼블릭 클라우드에 저장 가능한 법적 근거

금융 데이터를 퍼블릭 클라우드에 저장할 수 있는 근거는 단일 조문에서 “전면 허용”하는 방식이 아니라, 클라우드 이용을 전제로 한 절차ㆍ평가ㆍ보안조치ㆍ계약ㆍ보고 요건을 충족하면 이용할 수 있도록 하는 구조다.

- 클라우드컴퓨팅 발전 및 이용자 보호에 관한 법률 제21조: 다른 법령에서 인가ㆍ허가ㆍ등록ㆍ지정 요건으로 전산시설등을 요구하는 경우 해당 전산시설등에 클라우드컴퓨팅서비스가 포함되는 것으로 본다. 다만 해당 법령이 클라우드 이용을 명시적으로 금지하거나, 물리적 분리구축 등으로 사실상 제한하거나, 요구 요건을 충족하지 못하는 경우는 제외된다.
- 전자금융감독규정 제14조의2: 금융회사 또는 전자금융업자는 클라우드컴퓨팅법 제2조제3호의 클라우드컴퓨팅서비스를 이용할 수 있으며, 이용 시 업무 중요도 평가, CSP 건전성ㆍ안전성 평가, 업무 연속성 계획, 안전성 확보조치, 정보보호위원회 심의ㆍ의결, 사후보고 및 관련 서류 최신화 절차를 수행해야 한다.
- 금융보안원 「금융분야 클라우드컴퓨팅서비스 이용 가이드(2025 개정)」: 금융회사의 클라우드 이용은 정보처리 업무 위탁에 해당할 수 있고, 금융회사는 CSP가 관계 법령을 준수하도록 관리ㆍ감독해야 한다. 또한 중요도 평가, CSP 평가, 업무 연속성 계획, 안전성 확보조치, 계약, 보고, 이용 종료 및 데이터 이전ㆍ파기 절차를 갖추도록 안내한다.
- 금융회사의 정보처리 업무 위탁에 관한 규정: 고객정보가 수탁자에게 전달되는 경우 별도 관리방안, 인가된 자에 대한 접근권한 부여, 수탁자 모니터링, 감독당국 및 내외부 감사인의 조사ㆍ접근권, 계약 종료ㆍ중단ㆍ변경 시 데이터 반환ㆍ파기 절차를 요구한다.

따라서 이 Terraform의 S3 설계는 퍼블릭 클라우드 저장을 전제로 하되, 다음 조건을 충족하는 방향으로 구성한다.

- 원본 로그, 분석 결과, compliance 증적을 prefix로 분리한다.
- CloudTrail, AWS Config, VPC Flow Logs로 접근기록과 변경이력을 남긴다.
- S3 SSE-KMS, Public Access Block, bucket policy, SecureTransport deny를 적용한다.
- Athena 조회 결과와 원본 로그의 lifecycle을 분리한다.
- 고유식별정보 또는 개인신용정보가 포함될 가능성이 있는 데이터는 국내 리전, 최소 수집, 마스킹, 접근권한 분리, 보존기간 만료 후 삭제를 전제로 한다.

### 핀테크 기업 퍼블릭 클라우드 사용 시 준수사항

퍼블릭 클라우드 사용 시에는 기술 설정뿐 아니라 클라우드 이용 절차, 위탁관리, 보안통제, 보고자료 유지가 함께 필요하다.

1. 이용대상 업무 및 데이터 분류

- 클라우드에서 처리할 업무와 데이터를 식별한다.
- 전자금융거래정보, 금융정보, 개인신용정보, 고유식별정보, 업무정보, 공개정보를 분류한다.
- 고유식별정보 또는 개인신용정보 처리 여부를 별도로 표시한다.
- 원본 거래기록, AML 자료, 회계 장부 등 장기 법정 보존자료는 SOC 로그 bucket과 분리한다.

2. 업무 중요도 평가

- 전자금융감독규정 제14조의2 기준에 따라 업무 중요도를 평가한다.
- 업무 규모와 복잡성, 외부기관 연계 수, 내부 시스템 연계 수, 대고객 서비스 여부를 확인한다.
- 서비스 중단 시 영향, 손해금액, RTO를 평가한다.
- 침해사고 발생 시 고객 영향과 개인신용정보ㆍ고유식별정보 처리 여부를 평가한다.
- 동일 CSP 의존도와 멀티클라우드 또는 별도 백업 여부를 검토한다.

3. CSP 건전성ㆍ안전성 평가

- CSP의 재무ㆍ운영 건전성과 보안관리 수준을 평가한다.
- 클라우드 보안인증, 취약점 점검, 보안감사 로그, 장애대응, 침해사고 대응체계를 확인한다.
- 접근기록이 식별 가능한 형태로 기록ㆍ모니터링되고, 비인가 접근 및 변조로부터 보호되는지 확인한다.
- 재위탁 또는 서브프로세서가 있는 경우 변경 통보와 관리ㆍ감독 방안을 확인한다.

4. 업무 연속성 및 출구전략

- 업무연속성 계획과 재해복구계획을 수립한다.
- 백업, 복구목표시간(RTO), 복구목표시점(RPO), 비상연락체계, 모의훈련 계획을 정의한다.
- CSP 장애, 계약 종료, 서비스 중단, 품질 저하, 규제 변경 시 데이터 이전ㆍ반환ㆍ파기 절차를 마련한다.
- 특정 CSP 집중 리스크를 정기적으로 검토하고, 필요 시 멀티클라우드ㆍ별도 백업ㆍObject Lock 보관소를 검토한다.

5. 보안통제

- S3 Public Access Block, bucket policy, SecureTransport deny를 적용한다.
- 저장 데이터는 SSE-KMS로 암호화하고 KMS key rotation을 활성화한다.
- IAM 최소권한, MFA, 관리자 접근통제, 보안그룹 제한을 적용한다.
- CloudTrail, AWS Config, VPC Flow Logs를 활성화하고 중앙 S3에 적재한다.
- CloudTrail 로그 파일 검증, S3 versioning, Object Ownership, lifecycle을 적용한다.
- 개인정보 또는 개인신용정보가 포함될 가능성이 있는 로그는 마스킹, 최소 수집, 접근권한 분리를 적용한다.

6. 로그 보관 및 조회

- Production 접근기록은 `fin-prod-log-s3`에 저장한다.
- Staging 접근기록은 `fin-stg-log-s3`에 저장한다.
- Development 접근기록은 `fin-dev-log-s3`에 저장한다.
- SOC 접근기록은 `fin-athena-result-s3/soc-logs/`에 저장한다.
- CloudTrail, AWS Config, VPC Flow Logs 원본은 5년 보존한다.
- Athena 조회 결과는 목적별 prefix에 저장하고 재생성 가능성에 따라 7일, 30일, 3년, 5년으로 나눈다.
- 조사ㆍ분쟁ㆍ감독 대응 건은 lifecycle 대상 prefix에서 `legal-hold/` 또는 Object Lock 보관소로 승격한다.

7. 계약ㆍ보고ㆍ내부승인

- 중요도 평가 결과, CSP 평가 결과, 업무연속성 계획, 안전성 확보조치 방안을 정보보호위원회에서 심의ㆍ의결한다.
- 필요한 경우 최고경영자 또는 이사회 보고 절차를 따른다.
- 전자금융감독규정 제14조의2 보고 대상이면 정해진 기한 내 금융감독원 보고자료를 제출한다.
- 계약서에는 보안조치, 재위탁, 장애ㆍ침해사고 통보, 감사ㆍ조사 접근권, 데이터 반환ㆍ파기, 손해배상, 종료 지원을 포함한다.
- 클라우드 이용 관련 서류와 증적을 최신 상태로 유지한다.

### 선정 이유

- 전자금융거래법상 일반적인 “S3 로그 7년 삭제” 근거는 확인되지 않는다. 전자금융거래법 제22조와 시행령 제12조의 정확한 보존기간은 주요 전자금융거래기록 5년, 일부 기록 1년이다.
- 7년 보존은 국세기본법 제85조의3의 역외거래 장부ㆍ증거서류에 해당할 때 적용할 수 있는 별도 기준이다. 따라서 CloudTrail, AWS Config, VPC Flow Logs, Athena 분석 결과의 기본 lifecycle로 7년을 적용하지 않는다.
- 개인정보와 개인신용정보의 보존 기준은 구분한다. 일반 개인정보는 “5년 보관”이 원칙이 아니라 목적 달성 또는 보유기간 경과 시 파기하는 것이 원칙이고, 개인정보처리시스템 접속기록은 1년 또는 고위험 조건에서 2년 이상 보관한다.
- 개인신용정보는 신용정보법 제20조의2에 따라 금융거래 등 상거래관계 종료 후 최장 5년 이내 삭제가 기본이며, 목적이 더 빨리 달성된 경우 3개월 이내 삭제한다. 필수적 개인신용정보는 종료 후 분리 보관ㆍ접근제한을 적용하고, 선택적 신용정보는 3개월 내 삭제 대상으로 본다.
- Production, Development, Staging, SOC 원본 로그는 전자금융거래 추적, 이상거래 조사, 장애 및 사고 대응, CSP 장애ㆍ침해사고 책임 추적, 규제 감사 증적에 사용될 수 있어 5년 보존 후 삭제한다.
- `soc-logs/`는 CloudTrail, AWS Config, VPC Flow Logs 등 SOC 계정 자체 원본 로그를 모으는 prefix다. 클라우드 이용 가이드의 업무 연속성, 안전성 확보조치, 감독ㆍ감사 접근권 요구를 고려해 재생성 불가능한 원본 로그로 보고 5년 보존한다.
- Compliance baseline과 월간 감사보고서는 정보보호위원회 심의ㆍ의결, 클라우드 이용 보고, 내부통제, 감사 대응의 증적이므로 원본 로그와 동일하게 5년 보존한다.
- `athena-results/incident/`는 보안 사고 조사, 피해 분석, 감독기관 또는 내외부 감사 대응 근거가 될 수 있어 5년 보존한다.
- `athena-results/sc-audit/`, `athena-results/monthly-audit/`, `athena-results/compliance-result/`는 원본 로그에서 재실행 가능한 분석 결과이지만, 클라우드 이용 보고서류와 월간 점검 근거로 활용될 수 있어 3년 보존한다.
- `athena-results/ops/`와 `athena-results/ad-hoc/`는 운영성 반복 조회 결과이므로 30일 후 삭제한다.
- `athena-results/temp/`는 임시 산출물 전용 prefix이므로 7일 후 삭제한다.
- 비용 최적화를 위해 장기 보존 대상은 90일 이후 Standard-IA, 1년 이후 Glacier로 전환한다.
- 상법상 상업장부 10년 보존 대상, 국세기본법상 역외거래 7년 보존 대상, AML 원본 자료 등은 이 SOC 로그 bucket이 아니라 별도 원본 자료 저장소 또는 `legal-hold/`/Object Lock 정책으로 분리하는 것을 원칙으로 한다. 해당 자료를 S3에 저장해야 하는 경우에는 별도 prefix와 별도 lifecycle을 둔다.
- 개인정보 또는 개인신용정보가 포함될 가능성이 있는 로그는 최소 수집, 마스킹, 접근권한 분리, 분리 보관, 보존기간 만료 후 자동 삭제를 전제로 한다. 개인신용정보 원본 또는 식별 가능한 개인신용정보는 일반 SOC 로그 prefix가 아니라 별도 분리 보관 영역으로 관리한다.
- 클라우드서비스 전환 또는 종료 시에는 출구전략에 따라 데이터 이전, 반환, 파기를 수행해야 하므로, 공식 증적은 `monthly-audit/`ㆍ`baseline/`에, 재생성 가능한 조회 결과는 `athena-results/` 하위에, 원본 로그는 `soc-logs/`에 분리한다.
- 특정 CSP에 대한 집중 리스크와 데이터 이전 가능성을 고려해 prefix별 보존정책을 명확히 두고, 필요 시 `legal-hold/` 또는 Object Lock이 적용된 별도 보관소로 사고ㆍ분쟁 자료를 승격한다.

### Lifecycle 설정

`fin-prod-log-s3`:

```text
전체 객체
  90일 후 Standard-IA
  1년 후 Glacier
  5년 후 삭제
```

`fin-stg-log-s3`:

```text
전체 객체
  90일 후 Standard-IA
  1년 후 Glacier
  5년 후 삭제
```

`fin-athena-result-s3`:

```text
athena-results/temp/                7일 후 삭제
athena-results/ops/                 30일 후 삭제
athena-results/ad-hoc/              30일 후 삭제
athena-results/sc-audit/            90일 후 Standard-IA, 1년 후 Glacier, 3년 후 삭제
athena-results/monthly-audit/       90일 후 Standard-IA, 1년 후 Glacier, 3년 후 삭제
athena-results/compliance-result/   90일 후 Standard-IA, 1년 후 Glacier, 3년 후 삭제
athena-results/incident/            90일 후 Standard-IA, 1년 후 Glacier, 5년 후 삭제
soc-logs/                           90일 후 Standard-IA, 1년 후 Glacier, 5년 후 삭제
baseline/                           90일 후 Standard-IA, 1년 후 Glacier, 5년 후 삭제
monthly-audit/                      90일 후 Standard-IA, 1년 후 Glacier, 5년 후 삭제
tax-offshore-evidence/              90일 후 Standard-IA, 1년 후 Glacier, 7년 후 삭제
commercial-ledger/                  90일 후 Standard-IA, 1년 후 Glacier, 10년 후 삭제
legal-hold/                         lifecycle 미적용, 수동 보존 또는 Object Lock 별도 적용
```

7년ㆍ10년 보존 prefix의 용도:

```text
tax-offshore-evidence/
  국세기본법상 역외거래 장부ㆍ증거서류 등 7년 보존 대상 전용

commercial-ledger/
  상법상 상업장부ㆍ영업 중요서류 등 10년 보존 대상 전용
```

`tax-offshore-evidence/`와 `commercial-ledger/`는 CloudTrail, AWS Config, VPC Flow Logs 같은 SOC 원본 로그 보관을 위한 기본 prefix가 아니다. 전자금융거래법 제22조와 전자금융거래법 시행령 제12조 기준으로 일반 전자금융거래기록의 주된 보존기간은 5년이므로, SOC 로그 전체를 7년 또는 10년으로 잡지 않는다.

다만 핀테크 서비스 운영 과정에서 세무ㆍ회계 증빙 파일이 같은 S3 관리 체계에 들어올 수 있으므로, 법정 보존기간이 다른 자료를 원본 로그와 섞지 않기 위해 예외 prefix를 별도로 둔다. `tax-offshore-evidence/`는 국세기본법 제85조의3의 역외거래 장부ㆍ증거서류 7년 보존 가능성을 반영한 prefix이고, `commercial-ledger/`는 상법 제33조의 상업장부 및 영업에 관한 중요서류 10년 보존 기준을 반영한 prefix다.

이 두 prefix에 저장할 수 있는 것은 세무ㆍ회계 원본 증빙 또는 그 보존을 입증하기 위한 자료로 제한한다. 일반 접근기록, 보안 로그, Athena 임시 조회 결과, 월간 감사 리포트는 위 예외 prefix에 저장하지 않고 각각 `soc-logs/`, `athena-results/`, `monthly-audit/` lifecycle을 따른다. 장기 보존 대상인지 불명확하거나 분쟁ㆍ조사 중인 자료는 자동 삭제 대상 prefix가 아니라 `legal-hold/` 또는 Object Lock이 적용된 별도 보관소로 분리한다.

### 접근 기록 로그 보관 및 조회 구조

```text
AWS account activity
→ CloudTrail
→ S3 원본 로그 bucket/prefix
→ Glue Catalog table
→ Athena Workgroup
→ athena-results/sc-audit/ 또는 athena-results/incident/
```

- Production 계정 접근기록: `fin-prod-log-s3`에 적재한다.
- Staging 계정 접근기록: `fin-stg-log-s3`에 적재한다.
- Development 계정 접근기록: `fin-dev-log-s3`에 적재한다.
- SOC 계정 접근기록: `fin-athena-result-s3/soc-logs/cloudtrail/`에 적재한다.
- CloudTrail 원본 로그는 5년 보존하고, Athena 조회 결과는 재실행 가능한 산출물이므로 목적별로 30일ㆍ3년ㆍ5년으로 나눈다.
- 조사 또는 분쟁으로 보존 중단이 필요한 객체는 lifecycle 대상 prefix에서 `legal-hold/` 또는 Object Lock이 적용된 별도 bucket으로 이동한다.

## 다른 계정과의 역할 분리

SOC 계정에 모든 애플리케이션 데이터를 저장하지 않는다.

SOC 계정에 저장하는 것:

- 감사 로그
- 보안 로그
- 설정 변경 이력
- 네트워크 흐름 로그
- 보안 분석 결과
- 컴플라이언스 증빙

Production 계정에 저장하는 것:

- 전자금융거래 원본 기록
- AML 원본 자료
- DB 백업
- 애플리케이션 업무 데이터
- 운영 Athena 결과

Development 계정에 저장하는 것:

- 테스트 데이터
- 개발용 비운영 산출물

즉, SOC는 운영 원본 데이터의 소유자가 아니라 **중앙 로그/감사/관제 허브** 역할을 한다.

## Dev / Prod / Stage 연동 시 필요한 값

나중에 VPC Peering과 Cross-account 로그 적재를 연결할 때 `terraform.tfvars`에 아래 값을 넣는다.

```hcl
prod_vpc_peering_connection_id = "pcx-..."
dev_vpc_peering_connection_id  = "pcx-..."
stage_vpc_peering_connection_id = "pcx-..."

prod_account_id = "111122223333"
dev_account_id  = "444455556666"
stage_account_id = "777788889999"
```

SOC 쪽에서 이 값들을 넣으면:

- SOC Route Table에 Prod / Dev / Stage CIDR route가 추가된다.
- SOC S3 bucket policy가 Prod / Dev / Stage 로그 적재를 허용한다.
- SOC KMS key policy가 Prod / Dev / Stage 로그 서비스의 KMS 사용을 허용한다.

Prod / Dev / Stage 쪽에서도 반대 방향 route가 필요하다.

```text
Prod/Dev/Stage route table
→ 10.10.0.0/16
→ SOC VPC Peering Connection
```

## Corp VPN 연결

Corp(본사)와 Site-to-Site VPN 연결을 위한 EC2 기반 구성이다.

| 항목 | 값 |
|------|-----|
| VPN EC2 | `fin-soc-vpn-instance` |
| EIP | `terraform output vpn_fixed_ip` |
| Corp CIDR | `192.168.0.0/16` |
| PSK | 노션 참고 |

### VPN 설정

1. `terraform apply` 후 `vpn_fixed_ip` 를 Corp에 전달
2. Corp에서 VPN IP, PSK 전달받음
3. SSM 접속 후 Libreswan 설정

```bash
sudo ipsec status
```
성공 시: STATE_V2_ESTABLISHED_IKE_SA, STATE_V2_ESTABLISHED_CHILD_SA

## 로그 적재 방식

Prod / Staging / Development 계정은 각 계정의 CloudWatch Logs에 로그를 모은 뒤 SOC 계정의 환경별 로그 버킷으로 export한다. SOC 계정 자체 로그는 `fin-athena-result-s3`의 `soc-logs/` prefix로 보낸다.

연동 대상:

- CloudWatch Logs export task
- CloudTrail log group
- AWS Config log group
- VPC Flow Logs log group
- ALB Access Logs
- WAF Logs
- EKS Audit Logs, 필요 시

Athena는 Prod, Dev, Stage VPC에 직접 붙는 것이 아니라, S3 버킷에 적재된 로그 파일을 조회한다.

```text
Prod Logs → fin-prod-log-s3
Dev Logs  → fin-dev-log-s3
Stage Logs → fin-stg-log-s3
SOC Logs  → fin-athena-result-s3/soc-logs/
→ Glue Catalog / Athena
→ fin-athena-result-s3/athena-results/
```

SOC Terraform은 CloudTrail, AWS Config, SOC VPC Flow Logs를 직접 활성화하고 `fin-athena-result-s3/soc-logs/`로 적재한다. Production / Staging / Development 계정의 CloudWatch Logs export는 각 계정에서 실행하며, 이 Terraform은 export 대상 버킷과 `baseline/service-log-intake-manifest.json` 산출물을 준비한다.

## KMS 구성

현재 KMS는 EKS용이 아니라 SOC 로그 암호화용이다.

사용처:

- SOC S3 buckets SSE-KMS
- CloudTrail log encryption
- AWS Config delivery encryption
- VPC Flow Logs S3 delivery encryption
- Athena query result encryption

EKS NodeGroup / EBS 암호화를 구성할 경우에는 별도의 EKS/EBS KMS key를 만드는 것이 좋다. EKS Managed NodeGroup에서 EBS 암호화 KMS를 사용할 때는 Auto Scaling service-linked role에 KMS 권한이 필요하다.

## 규제 준수 모니터링

AWS Config Managed Rule을 통해 기본 보안 준수 상태를 점검한다.

포함된 점검:

- CloudTrail 활성화 여부
- S3 public read 차단 여부
- S3 public write 차단 여부
- S3 server-side encryption 활성화 여부
- VPC Flow Logs 활성화 여부
- SSH `0.0.0.0/0` 허용 여부
- IAM User MFA 활성화 여부
- Root Account MFA 활성화 여부

NON_COMPLIANT 상태 변경은 EventBridge를 통해 SNS Topic으로 전달된다.

ISMS-P 대응을 위해 `baseline/isms-p-control-mapping.json`을 `fin-athena-result-s3` bucket에 저장한다. 이 파일은 ISMS-P 기반 통제 항목, 증적 위치, 연결된 AWS Config Rule을 정의하며 월간 감사 Lambda 보고서에 포함된다.

## 정기 감사 자동화

현재 구현된 자동화:

- 매월 1일 EventBridge schedule 실행
- Lambda가 AWS Config 준수 결과와 Athena CloudTrail 월간 요약 쿼리를 실행
- 결과를 JSON 보고서와 CSV 파일로 생성
- 보고서를 `fin-athena-result-s3` bucket의 `monthly-audit/` prefix에 저장
- SOC 감사 SNS Topic으로 보고서 S3 위치와 요약 결과 발송
- Athena named query로 월간 CloudTrail 활동 요약 쿼리 제공
- 보고서 보관 위치로 `fin-athena-result-s3` bucket 사용

주의할 점:

- 최초 적용 후 SNS 이메일 구독 확인 메일을 승인해야 담당자가 알림을 받는다.
- Athena named query의 테이블 생성 쿼리는 먼저 실행되어 `cloudtrail_logs`, `vpc_flow_logs` 테이블이 만들어져 있어야 월간 Lambda의 Athena 요약이 성공한다.
- Production / Development / Staging 계정에는 `fin-cloudwatch-export-role` IAM Role을 만들고, SOC 중앙 Lambda Role이 AssumeRole 할 수 있도록 trust policy를 설정해야 한다.
- CloudWatch Logs export는 계정과 리전별 active export task 제한이 있으므로, 중앙 Lambda는 active task가 있으면 해당 계정을 건너뛴다.

## 알림 이메일 설정

`terraform.tfvars`에서 이메일을 설정하면 SNS 구독이 생성된다.

```hcl
audit_notification_email = "your-email@example.com"
```

AWS에서 구독 확인 메일이 발송되며, 수신자가 Confirm 해야 알림이 실제로 전달된다.

## 실행 방법

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

개인 환경값은 `terraform.tfvars.example`을 참고해 `terraform.tfvars`를 로컬에서 만들어 사용한다.

## GitHub에 올리면 안 되는 파일

아래 파일은 민감 정보나 로컬 상태를 포함할 수 있으므로 커밋하지 않는다.

```text
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
.terraform/
*.tfplan
.venv/
.DS_Store
```

특히 `terraform.tfstate`에는 실제 AWS 계정 ID, ARN, KMS ARN, 버킷명 등이 포함될 수 있다.

공유는 `terraform.tfvars.example`만 사용한다.
