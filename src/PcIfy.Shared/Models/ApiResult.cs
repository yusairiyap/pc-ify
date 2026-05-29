namespace PcIfy.Shared.Models;

public class ApiResult<T>
{
    public bool Success { get; set; }
    public T? Data { get; set; }
    public string? Error { get; set; }

    public static ApiResult<T> Ok(T data) => new() { Success = true, Data = data };
    public static ApiResult<T> Fail(string error) => new() { Success = false, Error = error };
}

public class ApiResult
{
    public bool Success { get; set; }
    public string? Error { get; set; }

    public static ApiResult Ok() => new() { Success = true };
    public static ApiResult Fail(string error) => new() { Success = false, Error = error };
}
