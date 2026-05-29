using System.Globalization;
using PcIfy.Shared.DTOs.Files;

namespace PcIfy.Client.Converters;

public class FileTypeToIconConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        return value is FileType type ? type switch
        {
            FileType.Folder   => "📁",
            FileType.Video    => "🎬",
            FileType.Image    => "🖼️",
            FileType.Audio    => "🎵",
            FileType.Document => "📄",
            FileType.Archive  => "🗜️",
            _                 => "📎"
        } : "📎";
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
