DECLARE @Where NVARCHAR(MAX) = '1 = 0';

SELECT TOP (1) @Where = 'TopRunId = ' + CAST(TopRunId AS NVARCHAR(MAX))
FROM dbo.t_Load_FileMonitor
WHERE FileName LIKE 'BBO\_SEC\__.psv' ESCAPE '\'
ORDER BY TopRunId DESC

EXEC dbo.[usp_Core_Query] 
	@TableSchema = 'dbo',
	@TableName = 't_Load_BBO_SEC_Store',
	@ColumnAction = 'E',
	@ColumnList = '%RUNID, CADIS\_SYSTEM\_%',
    @Where = @Where,
    @OrderBy = 'FileNum, RowNum'

