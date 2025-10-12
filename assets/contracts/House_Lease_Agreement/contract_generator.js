// 계약서 생성 및 업데이트 함수
class ContractGenerator {
    constructor() {
        this.contractData = {};
    }

    // 사용자 입력 데이터를 받아서 계약서 생성
    async generateContract(formData) {
        this.contractData = formData;
        
        try {
            // 각 페이지별로 데이터 적용
            await this.updatePage1();
            await this.updatePage2();
            await this.updatePage3();
            await this.updatePage4();
            await this.updatePage5();
            
            // 성공 메시지
            this.showSuccess();
            
        } catch (error) {
            console.error('계약서 생성 중 오류:', error);
            this.showError(error.message);
        }
    }

    // 1페이지 업데이트 (기본 정보, 부동산 정보, 금액)
    async updatePage1() {
        const page1Content = await this.loadHTMLFile('House_Lease_Agreement_1.html');
        let updatedContent = page1Content;

        // 임대인/임차인 정보 업데이트
        updatedContent = this.replaceText(updatedContent, 
            '이름 또는 법인명 기재', 
            this.contractData.landlord_name || '이름 또는 법인명 기재'
        );

        // 소재지 업데이트
        updatedContent = this.replaceInInputField(updatedContent, 
            '소재지', 
            this.contractData.property_address || ''
        );

        // 토지 정보 업데이트
        updatedContent = this.updateTableCell(updatedContent, '지목', this.contractData.land_purpose || '');
        updatedContent = this.updateTableCell(updatedContent, '토지.*면적', this.contractData.land_area || '');

        // 건물 정보 업데이트
        updatedContent = this.updateTableCell(updatedContent, '구조‧용도', this.contractData.building_structure || '');
        updatedContent = this.updateTableCell(updatedContent, '건물.*면적', this.contractData.building_area || '');

        // 임차할부분 업데이트
        updatedContent = this.updateTableCell(updatedContent, '임차할부분', this.contractData.rental_part || '');
        updatedContent = this.updateTableCell(updatedContent, '임차할부분.*면적', this.contractData.rental_area || '');

        // 계약 종류 체크박스 업데이트
        updatedContent = this.updateContractType(updatedContent);

        // 금액 정보 업데이트
        updatedContent = this.updateMoneyFields(updatedContent);

        // 임대차 기간 업데이트
        updatedContent = this.updateContractPeriod(updatedContent);

        // 수리 정보 업데이트
        updatedContent = this.updateRepairInfo(updatedContent);

        // 파일 저장
        await this.saveHTMLFile('House_Lease_Agreement_1.html', updatedContent);
    }

    // 2페이지 업데이트 (조항 내용)
    async updatePage2() {
        const page2Content = await this.loadHTMLFile('House_Lease_Agreement_2.html');
        let updatedContent = page2Content;

        // 특약사항 업데이트
        if (this.contractData.special_terms) {
            updatedContent = this.updateSpecialTerms(updatedContent);
        }

        await this.saveHTMLFile('House_Lease_Agreement_2.html', updatedContent);
    }

    // 3페이지 업데이트 (서명 정보)
    async updatePage3() {
        const page3Content = await this.loadHTMLFile('House_Lease_Agreement_3.html');
        let updatedContent = page3Content;

        // 임대인 정보 업데이트
        updatedContent = this.updateSignatureInfo(updatedContent, 'landlord');
        
        // 임차인 정보 업데이트
        updatedContent = this.updateSignatureInfo(updatedContent, 'tenant');

        // 공인중개사 정보 업데이트
        updatedContent = this.updateAgentInfo(updatedContent);

        await this.saveHTMLFile('House_Lease_Agreement_3.html', updatedContent);
    }

    // 4페이지 업데이트 (법적 보호 사항)
    async updatePage4() {
        const page4Content = await this.loadHTMLFile('House_Lease_Agreement_4.html');
        // 4페이지는 주로 법적 안내사항이므로 특별한 업데이트 없음
        await this.saveHTMLFile('House_Lease_Agreement_4.html', page4Content);
    }

    // 5페이지 업데이트 (계약갱신거절통지서)
    async updatePage5() {
        const page5Content = await this.loadHTMLFile('House_Lease_Agreement_5.html');
        let updatedContent = page5Content;

        // 임대인/임차인 정보 업데이트
        updatedContent = this.updateNoticeForm(updatedContent);

        await this.saveHTMLFile('House_Lease_Agreement_5.html', updatedContent);
    }

    // 텍스트 교체 함수
    replaceText(content, searchText, replaceText) {
        const regex = new RegExp(searchText, 'g');
        return content.replace(regex, replaceText);
    }

    // 입력 필드 업데이트
    replaceInInputField(content, labelText, value) {
        // 라벨 다음에 오는 빈 입력 영역을 찾아서 값 삽입
        const regex = new RegExp(`(${labelText}.*?<div[^>]*>\\s*<div[^>]*>\\s*<div[^>]*>\\s*)(</div>)`, 's');
        return content.replace(regex, `$1<span class="hrt cs106">${value}</span>$2`);
    }

    // 테이블 셀 업데이트
    updateTableCell(content, labelText, value) {
        if (!value) return content;
        
        // 라벨이 있는 셀 다음의 빈 셀을 찾아서 값 삽입
        const regex = new RegExp(`(${labelText}.*?</div>.*?<div[^>]*>\\s*<div[^>]*>\\s*<div[^>]*>\\s*)(</div>)`, 's');
        return content.replace(regex, `$1<span class="hrt cs106">${value}</span>$2`);
    }

    // 계약 종류 업데이트
    updateContractType(content) {
        let updatedContent = content;
        
        // 기존 체크박스 표시 제거
        updatedContent = updatedContent.replace(/☑/g, '☐');
        
        // 선택된 계약 종류에 체크 표시
        switch (this.contractData.contract_type) {
            case 'new':
                updatedContent = updatedContent.replace('☐ 신규 계약', '☑ 신규 계약');
                break;
            case 'renewal':
                updatedContent = updatedContent.replace('☐ 합의에 의한 재계약', '☑ 합의에 의한 재계약');
                break;
            case 'extension':
                updatedContent = updatedContent.replace('☐ 계약갱신요구권', '☑ 계약갱신요구권');
                break;
        }

        // 임대차 유형 업데이트
        if (this.contractData.rental_type === 'jeonse') {
            updatedContent = updatedContent.replace('☐ 전세', '☑ 전세');
        } else if (this.contractData.rental_type === 'monthly') {
            updatedContent = updatedContent.replace('☐ 보증금 있는 월세', '☑ 보증금 있는 월세');
        }

        return updatedContent;
    }

    // 금액 필드 업데이트
    updateMoneyFields(content) {
        let updatedContent = content;

        // 보증금
        if (this.contractData.deposit) {
            const depositKorean = this.numberToKorean(this.contractData.deposit);
            updatedContent = this.replaceMoneyField(updatedContent, '보증금', this.contractData.deposit, depositKorean);
        }

        // 계약금
        if (this.contractData.contract_money) {
            const contractKorean = this.numberToKorean(this.contractData.contract_money);
            updatedContent = this.replaceMoneyField(updatedContent, '계약금', this.contractData.contract_money, contractKorean);
        }

        // 중도금
        if (this.contractData.interim_money) {
            const interimKorean = this.numberToKorean(this.contractData.interim_money);
            updatedContent = this.replaceMoneyField(updatedContent, '중도금', this.contractData.interim_money, interimKorean);
            
            // 중도금 지급일
            if (this.contractData.interim_date) {
                const date = new Date(this.contractData.interim_date);
                updatedContent = this.replaceDateField(updatedContent, '중도금.*년.*월.*일', date);
            }
        }

        // 잔금
        if (this.contractData.balance) {
            const balanceKorean = this.numberToKorean(this.contractData.balance);
            updatedContent = this.replaceMoneyField(updatedContent, '잔금', this.contractData.balance, balanceKorean);
            
            // 잔금 지급일
            if (this.contractData.balance_date) {
                const date = new Date(this.contractData.balance_date);
                updatedContent = this.replaceDateField(updatedContent, '잔금.*년.*월.*일', date);
            }
        }

        // 월세
        if (this.contractData.monthly_rent_amount) {
            updatedContent = this.replaceMoneyField(updatedContent, '차임', this.contractData.monthly_rent_amount);
            
            // 월세 지급일
            if (this.contractData.rent_payment_day) {
                updatedContent = updatedContent.replace(/매월\s*일에/, `매월 ${this.contractData.rent_payment_day}일에`);
            }
        }

        // 입금계좌
        if (this.contractData.bank_account) {
            updatedContent = updatedContent.replace(/입금계좌:\s*\)/, `입금계좌: ${this.contractData.bank_account})`);
        }

        return updatedContent;
    }

    // 금액 필드 교체
    replaceMoneyField(content, fieldName, amount, korean = '') {
        const formattedAmount = Number(amount).toLocaleString();
        const regex = new RegExp(`(${fieldName}.*?금\\s*)(원정)`, 's');
        return content.replace(regex, `$1${formattedAmount}$2${korean ? `(₩ ${korean})` : ''}`);
    }

    // 날짜 필드 교체
    replaceDateField(content, pattern, date) {
        const year = date.getFullYear();
        const month = date.getMonth() + 1;
        const day = date.getDate();
        
        const regex = new RegExp(pattern, 'g');
        return content.replace(regex, `${year}년 ${month}월 ${day}일`);
    }

    // 계약 기간 업데이트
    updateContractPeriod(content) {
        let updatedContent = content;

        // 인도일
        if (this.contractData.handover_date) {
            const handoverDate = new Date(this.contractData.handover_date);
            updatedContent = this.replaceDateField(updatedContent, '인도일로부터.*년.*월.*일까지', handoverDate);
        }

        // 계약 시작일
        if (this.contractData.contract_start) {
            const startDate = new Date(this.contractData.contract_start);
            updatedContent = this.replaceDateField(updatedContent, '임대차기간.*년.*월.*일까지', startDate);
        }

        // 계약 종료일
        if (this.contractData.contract_end) {
            const endDate = new Date(this.contractData.contract_end);
            updatedContent = this.replaceDateField(updatedContent, '계약.*종료.*년.*월.*일', endDate);
        }

        return updatedContent;
    }

    // 수리 정보 업데이트
    updateRepairInfo(content) {
        let updatedContent = content;

        // 수리 필요 여부
        if (this.contractData.repair_needed === 'none') {
            updatedContent = updatedContent.replace('☐ 없음', '☑ 없음');
        } else if (this.contractData.repair_needed === 'has') {
            updatedContent = updatedContent.replace('☐ 있음', '☑ 있음');
            
            // 수리 내용
            if (this.contractData.repair_content) {
                updatedContent = updatedContent.replace(/수리할 내용:.*?\)/, `수리할 내용: ${this.contractData.repair_content})`);
            }
        }

        return updatedContent;
    }

    // 서명 정보 업데이트
    updateSignatureInfo(content, type) {
        let updatedContent = content;
        const prefix = type === 'landlord' ? 'landlord' : 'tenant';

        // 성명
        const name = this.contractData[`${prefix}_name`];
        if (name) {
            updatedContent = this.updateTableField(updatedContent, `${type}.*성명`, name);
        }

        // 주소
        const address = this.contractData[`${prefix}_address`];
        if (address) {
            updatedContent = this.updateTableField(updatedContent, `${type}.*주소`, address);
        }

        // 연락처
        const phone = this.contractData[`${prefix}_phone`];
        if (phone) {
            updatedContent = this.updateTableField(updatedContent, `${type}.*연락처`, phone);
        }

        // 주민등록번호
        const id = this.contractData[`${prefix}_id`];
        if (id) {
            updatedContent = this.updateTableField(updatedContent, `${type}.*주민등록번호`, id);
        }

        return updatedContent;
    }

    // 공인중개사 정보 업데이트
    updateAgentInfo(content) {
        let updatedContent = content;

        if (this.contractData.agent_name) {
            updatedContent = this.updateTableField(updatedContent, '중개업자.*성명', this.contractData.agent_name);
        }

        if (this.contractData.agent_license) {
            updatedContent = this.updateTableField(updatedContent, '등록번호', this.contractData.agent_license);
        }

        if (this.contractData.agent_address) {
            updatedContent = this.updateTableField(updatedContent, '중개사무소.*주소', this.contractData.agent_address);
        }

        if (this.contractData.agent_phone) {
            updatedContent = this.updateTableField(updatedContent, '중개사무소.*전화', this.contractData.agent_phone);
        }

        return updatedContent;
    }

    // 테이블 필드 업데이트
    updateTableField(content, labelPattern, value) {
        const regex = new RegExp(`(${labelPattern}.*?<div[^>]*>\\s*<div[^>]*>\\s*<div[^>]*>\\s*)(</div>)`, 's');
        return content.replace(regex, `$1<span class="hrt cs83">${value}</span>$2`);
    }

    // 숫자를 한글로 변환 (간단 버전)
    numberToKorean(number) {
        const units = ['', '만', '억', '조'];
        const digits = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
        
        if (number === 0) return '영';
        
        let result = '';
        let unitIndex = 0;
        
        while (number > 0) {
            const chunk = number % 10000;
            if (chunk > 0) {
                result = this.chunkToKorean(chunk) + units[unitIndex] + result;
            }
            number = Math.floor(number / 10000);
            unitIndex++;
        }
        
        return result;
    }

    chunkToKorean(chunk) {
        const digits = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
        const positions = ['', '십', '백', '천'];
        
        let result = '';
        let pos = 0;
        
        while (chunk > 0) {
            const digit = chunk % 10;
            if (digit > 0) {
                result = digits[digit] + positions[pos] + result;
            }
            chunk = Math.floor(chunk / 10);
            pos++;
        }
        
        return result;
    }

    // HTML 파일 로드 (실제 구현에서는 fetch 사용)
    async loadHTMLFile(filename) {
        try {
            const response = await fetch(filename);
            return await response.text();
        } catch (error) {
            console.error(`파일 로드 실패: ${filename}`, error);
            throw new Error(`파일을 불러올 수 없습니다: ${filename}`);
        }
    }

    // HTML 파일 저장 (브라우저에서는 다운로드로 처리)
    async saveHTMLFile(filename, content) {
        const blob = new Blob([content], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // 성공 메시지 표시
    showSuccess() {
        alert('계약서가 성공적으로 생성되었습니다!\n각 페이지가 다운로드됩니다.');
    }

    // 오류 메시지 표시
    showError(message) {
        alert(`계약서 생성 중 오류가 발생했습니다:\n${message}`);
    }
}

// 전역 인스턴스 생성
const contractGenerator = new ContractGenerator();

// 계약서 생성 함수 (contract_input.html에서 호출)
function generateContract(data) {
    contractGenerator.generateContract(data);
} 