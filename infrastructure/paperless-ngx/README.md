# Paperless-NGX

Paperless-NGX is a document management system that transforms your physical documents into a searchable online archive.

## Components

- **Paperless-NGX**: Main application
- **PostgreSQL**: Database
- **Redis**: Task queue and cache
- **Tika**: Document text extraction
- **Gotenberg**: PDF conversion

## Access

- URL: https://paperless.example.com
- Default admin user will be created on first run

## Storage

- Documents: `/usr/src/paperless/media`
- Data: `/usr/src/paperless/data`
- Database: PostgreSQL persistent volume

## Configuration

Environment variables are configured via ConfigMap and Secrets.