export function generateRandomChannelName(platform: string = 'rn'): string {
  const random = Math.floor(Math.random() * 9000) + 1000;
  return `channel_${platform}_${random}`;
}

