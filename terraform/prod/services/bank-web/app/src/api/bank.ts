import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://openapi-backend:8080/v1';

export const getBankDetail = async ({
  bankId,
  apiKey,
}: {
  bankId: string;
  apiKey: string;
}): Promise<any> => {
  const response = await axios.get(`${API_URL}/bank/${bankId}`, {
    headers: { 'Content-Type': 'application/json', apiKey },
  });
  return response.data;
};
