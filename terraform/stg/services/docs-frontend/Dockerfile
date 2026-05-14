# ============================================
# docs-frontend — Swagger UI for OpenAPI docs
# ============================================
# JOA 원본에 별도 docs 프론트엔드 소스가 없으므로
# Swagger UI 컨테이너로 API 문서를 제공합니다.
# openapi-backend의 /v3/api-docs 엔드포인트를 사용합니다.

FROM swaggerapi/swagger-ui:latest

ENV SWAGGER_JSON_URL=http://openapi-backend:8080/v3/api-docs
ENV BASE_URL=/docs
ENV PORT=3000

EXPOSE 3000
