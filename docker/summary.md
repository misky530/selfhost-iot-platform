# 1 测试timesacle是否正常
```bash
# 等几秒让健康检查完成，再查看状态
Start-Sleep -Seconds 10
docker-compose ps

# 查看日志确认数据库已就绪
docker-compose logs timescaledb --tail 10

# 测试连接（可选）
docker exec -it timescaledb psql -U postgres -d iot_data -c "SELECT version();"
```
