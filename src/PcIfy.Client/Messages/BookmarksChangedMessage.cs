using CommunityToolkit.Mvvm.Messaging.Messages;

namespace PcIfy.Client.Messages;

public class BookmarksChangedMessage : ValueChangedMessage<string>
{
    public BookmarksChangedMessage() : base(string.Empty) { }
}
