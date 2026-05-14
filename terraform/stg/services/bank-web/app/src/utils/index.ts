import { IProduct, ProductPaymentType, ProductType, productTypeName } from '@/models/product';

export const formatAmount = (n: number) => {
  const formatter = new Intl.NumberFormat('en-US');
  return formatter.format(n);
};

export const formatDate = (date: Date) => {
  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
};

export const getProductTypeName = (type: ProductType) => {
  return productTypeName.find(p => p.type === type);
};

export const calculateRate = (
  product: IProduct,
  amount: number,
  term: number,
  taxType: 'TAX' | 'NO_TAX',
) => {
  let calculatedInterest = 0;
  let totalPrincipal = amount;

  if (product.productType === 'TERM_DEPOSIT') {
    calculatedInterest = calculateTermDeposit(amount, product.rate, term, product.paymentType);
  } else if (product.productType === 'FIXED_DEPOSIT') {
    calculatedInterest = calculateFixedDeposit(amount, product.rate, term, product.paymentType);
    totalPrincipal *= term;
  }

  let taxInterest = 0;
  if (taxType === 'TAX') {
    taxInterest = (calculatedInterest * 154) / 1000;
  }

  let totalAmount = totalPrincipal + calculatedInterest - taxInterest;

  return { totalPrincipal, calculatedInterest, taxInterest, totalAmount };
};

const calculateTermDeposit = (
  principal: number,
  rate: number,
  term: number,
  paymentType: ProductPaymentType,
) => {
  let monthlyInterestRate = rate / 12 / 100;
  if (paymentType === 'SIMPLE') {
    return principal * monthlyInterestRate * term;
  } else {
    let totalAmount = principal * Math.pow(1 + monthlyInterestRate, term);
    return totalAmount - principal;
  }
};

const calculateFixedDeposit = (
  monthlyDeposit: number,
  rate: number,
  term: number,
  paymentType: ProductPaymentType,
) => {
  if (paymentType === 'SIMPLE') {
    return (((monthlyDeposit * term * (term + 1)) / 2) * rate) / 12 / 100;
  } else {
    let monthlyInterestRate = rate / 12 / 100;
    let interest = 0;
    for (let i = 0; i < term; i++) {
      interest += monthlyDeposit * (Math.pow(1 + monthlyInterestRate, term - i) - 1);
    }
    return interest;
  }
};
