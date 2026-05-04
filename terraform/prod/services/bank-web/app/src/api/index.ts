import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://openapi-backend:8080/v1';
const MEMBER_API_URL = process.env.NEXT_PUBLIC_MEMBER_API_URL || 'http://bank-backend:8080';
const API_KEY = process.env.NEXT_PUBLIC_API_KEY || '';

export const axiosInstance = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
    apiKey: API_KEY,
  },
});

export const memberAxiosInstance = axios.create({
  baseURL: MEMBER_API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});
